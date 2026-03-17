package main

import (
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"

	"C"

	tg "github.com/amarnathcjd/gogram/telegram"
)

type TGFetcher struct {
	client      *tg.Client
	sessionStr  string
	initialized bool
}

var (
	globalFetcher *TGFetcher
	globalMu      = &sync.Mutex{}

	msgLocCache = sync.Map{} // key: int32 (msgID), value: tg.InputFileLocation
	msgDCCache  = sync.Map{} // key: int32 (msgID), value: int32
	msgCache    = sync.Map{} // key: int32 (msgID), value: *tg.NewMessage

	streamingServerStarted bool
	streamingPort          int
)

func ensureClientInitialized() error {
	if globalFetcher == nil {
		return fmt.Errorf("not initialized")
	}
	if globalFetcher.client != nil {
		return nil
	}
	if globalFetcher.sessionStr == "" {
		return fmt.Errorf("no session string")
	}

	config := tg.ClientConfig{
		StringSession: globalFetcher.sessionStr,
		NoUpdates:     true,
		DisableCache:  true,
		MemorySession: true,
		CacheSenders:  true, // Enable worker reuse for DownloadChunk
		AppID:         1822414,
		AppHash:       "46f1888d3f68396bad08c92ac4d7f00a",
	}
	client, err := tg.NewClient(config)
	if err != nil {
		return err
	}
	globalFetcher.client = client
	globalFetcher.initialized = true
	if err := client.Connect(); err != nil {
		return err
	}

	return nil
}

//export CreateSessionFromBotToken
func CreateSessionFromBotToken(botToken *C.char) *C.char {
	token := C.GoString(botToken)
	globalMu.Lock()
	defer globalMu.Unlock()

	bot, err := tg.NewClient(tg.ClientConfig{
		Session:       "tg_session",
		NoUpdates:     true,
		DisableCache:  true,
		MemorySession: true,
		AppID:         1822414,
		AppHash:       "46f1888d3f68396bad08c92ac4d7f00a",
	})
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("failed to create client: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	if err := bot.Connect(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("failed to connect: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	if err := bot.LoginBot(token); err != nil {
		result := map[string]any{"error": fmt.Sprintf("failed to login: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	sessionStr := bot.ExportStringSession()

	result := map[string]any{
		"success": true,
		"session": sessionStr,
	}
	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

//export InitTGFetcher
func InitTGFetcher(sessionStrArg *C.char) *C.char {
	sessionStr := C.GoString(sessionStrArg)
	globalMu.Lock()
	defer globalMu.Unlock()

	if sessionStr == "" {
		result := map[string]any{"error": "empty session string"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	globalFetcher = &TGFetcher{sessionStr: sessionStr, initialized: false}

	if err := ensureClientInitialized(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("client init failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	me, err := globalFetcher.client.GetMe()
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("get me failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	result := map[string]any{
		"success":  true,
		"username": me.Username,
	}
	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

//export ResolveUsername
func ResolveUsername(usernameArg *C.char) *C.char {
	username := C.GoString(usernameArg)
	username = strings.TrimPrefix(username, "@")
	globalMu.Lock()
	defer globalMu.Unlock()

	if err := ensureClientInitialized(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("client init failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	peer, err := globalFetcher.client.ResolveUsername(username)
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("resolve failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	var channelID int64
	var accessHash int64

	switch p := peer.(type) {
	case *tg.Channel:
		channelID = p.ID
		accessHash = p.AccessHash
	case *tg.ChatObj:
		channelID = p.ID
		accessHash = 0
	case *tg.InputPeerChannel:
		channelID = p.ChannelID
		accessHash = p.AccessHash
	case *tg.InputPeerUser:
		result := map[string]any{"error": "resolved to user, expected channel/megagroup"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	case *tg.InputPeerChat:
		result := map[string]any{"error": "resolved to chat, expected channel/megagroup"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	default:
		result := map[string]any{"error": "resolved to unknown peer type"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	result := map[string]any{
		"success":     true,
		"channel_id":  channelID,
		"access_hash": accessHash,
	}
	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

//export FetchFileMetadata
func FetchFileMetadata(channelId C.longlong, accessHash C.longlong, msgID int32) *C.char {
	if err := ensureClientInitialized(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("client init failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	msg, err := getMsg(int64(channelId), int64(accessHash), msgID)
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("get message failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	doc := msg.Document()
	if doc == nil {
		result := map[string]any{"error": "no document in message"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	loc, dc, _, _, err := tg.GetFileLocation(msg.Media())
	if err == nil { // Best effort cache population
		msgLocCache.Store(msgID, loc)
		msgDCCache.Store(msgID, dc)
	}

	result := map[string]any{
		"success":   true,
		"size":      doc.Size,
		"mime_type": doc.MimeType,
		"msg_id":    msgID,
	}
	if msg.File != nil {
		result["name"] = msg.File.Name
	}

	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

func getMsg(channelId int64, accessHash int64, msgID int32) (*tg.NewMessage, error) {
	if val, ok := msgCache.Load(msgID); ok {
		return val.(*tg.NewMessage), nil
	}
	globalMu.Lock()
	defer globalMu.Unlock()
	if val, ok := msgCache.Load(msgID); ok {
		return val.(*tg.NewMessage), nil
	}
	peer := &tg.InputPeerChannel{ChannelID: channelId, AccessHash: accessHash}
	msg, err := globalFetcher.client.GetMessageByID(peer, msgID)
	if err != nil {
		return nil, err
	}
	msgCache.Store(msgID, msg)
	return msg, nil
}

//export DownloadFileChunk
func DownloadFileChunk(channelId C.longlong, accessHash C.longlong, msgID int32, start C.longlong, end C.longlong) *C.char {
	if err := ensureClientInitialized(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("client init failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	msg, err := getMsg(int64(channelId), int64(accessHash), msgID)
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("get message failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	totalSize := int64(end - start)
	if totalSize <= 0 {
		result := map[string]any{"error": "invalid start/end offsets"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	buf := make([]byte, totalSize)
	const chunkSize = 1048576 // 1MB chunks

	var wg sync.WaitGroup
	errCh := make(chan error, 1)

	// Use a semaphore to limit concurrency
	sem := make(chan struct{}, 8)

	for offset := int64(start); offset < int64(end); {
		alignedOffset := (offset / int64(chunkSize)) * int64(chunkSize)
		alignedEnd := alignedOffset + int64(chunkSize)

		wg.Add(1)
		go func(off int64, ao int64, ae int64) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			// Use gogram's DownloadChunk directly
			data, _, err := globalFetcher.client.DownloadChunk(msg, int(ao), int(ae), chunkSize)
			if err != nil {
				select {
				case errCh <- err:
				default:
				}
				return
			}
			if len(data) == 0 {
				select {
				case errCh <- errors.New("empty chunk received"):
				default:
				}
				return
			}

			skip := off - ao
			chunkData := data
			if skip > 0 && skip < int64(len(chunkData)) {
				chunkData = chunkData[skip:]
			}

			copyLen := int64(len(chunkData))
			if off-int64(start)+copyLen > totalSize {
				copyLen = totalSize - (off - int64(start))
			}

			if copyLen > 0 {
				copy(buf[off-int64(start):], chunkData[:copyLen])
			}
		}(offset, alignedOffset, alignedEnd)

		nextOffset := min(alignedEnd, int64(end))
		offset = nextOffset
	}

	wg.Wait()

	select {
	case err := <-errCh:
		result := map[string]any{"error": fmt.Sprintf("download failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	default:
	}

	hexData := hex.EncodeToString(buf)
	result := map[string]any{
		"success": true,
		"data":    hexData,
		"size":    len(buf),
	}

	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

//export DownloadFile
func DownloadFile(channelId C.longlong, accessHash C.longlong, msgID int32, filePathArg *C.char) *C.char {
	filePath := C.GoString(filePathArg)
	globalMu.Lock()
	defer globalMu.Unlock()

	if err := ensureClientInitialized(); err != nil {
		result := map[string]any{"error": fmt.Sprintf("client init failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	peer := &tg.InputPeerChannel{ChannelID: int64(channelId), AccessHash: int64(accessHash)}
	msg, err := globalFetcher.client.GetMessageByID(peer, msgID)
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("get message failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	doc := msg.Document()
	if doc == nil {
		result := map[string]any{"error": "no document"}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}

	file, err := os.Create(filePath)
	if err != nil {
		result := map[string]any{"error": fmt.Sprintf("create file failed: %v", err)}
		data, _ := json.Marshal(result)
		return C.CString(string(data))
	}
	defer file.Close()

	chunkSize := 1048576
	totalSize := doc.Size

	for offset := int64(0); offset < totalSize; {
		alignedOffset := (offset / int64(chunkSize)) * int64(chunkSize)
		alignedEnd := alignedOffset + int64(chunkSize)
		if alignedEnd > totalSize {
			alignedEnd = totalSize
		}

		chunkData, _, err := globalFetcher.client.DownloadChunk(msg, int(alignedOffset), int(alignedEnd), chunkSize)
		if err != nil {
			result := map[string]any{"error": fmt.Sprintf("chunk download failed: %v", err)}
			data, _ := json.Marshal(result)
			return C.CString(string(data))
		}

		if len(chunkData) == 0 {
			break
		}

		if _, err := file.Write(chunkData); err != nil {
			result := map[string]any{"error": fmt.Sprintf("write failed: %v", err)}
			data, _ := json.Marshal(result)
			return C.CString(string(data))
		}

		offset += int64(len(chunkData))
	}

	result := map[string]any{
		"success": true,
		"path":    filePath,
		"size":    totalSize,
	}
	data, _ := json.Marshal(result)
	return C.CString(string(data))
}

//export EncodeHash
func EncodeHash(msgID int32) *C.char {
	b := make([]byte, 4)
	binary.BigEndian.PutUint32(b, uint32(msgID))
	return C.CString(hex.EncodeToString(b))
}

//export DecodeHash
func DecodeHash(hashArg *C.char) C.int {
	hash := C.GoString(hashArg)
	b, err := hex.DecodeString(hash)
	if err != nil || len(b) != 4 {
		return -1
	}
	return C.int(int32(binary.BigEndian.Uint32(b)))
}

//export StartStreamingServer
func StartStreamingServer() C.int {
	globalMu.Lock()
	if streamingServerStarted {
		port := streamingPort
		globalMu.Unlock()
		return C.int(port)
	}
	globalMu.Unlock()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return -1
	}

	port := listener.Addr().(*net.TCPAddr).Port
	globalMu.Lock()
	streamingPort = port
	streamingServerStarted = true
	globalMu.Unlock()

	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/stream", handleStream)
		http.Serve(listener, mux)
	}()

	return C.int(port)
}

func handleStream(w http.ResponseWriter, r *http.Request) {
	msgIDStr := r.URL.Query().Get("msg_id")
	channelIDStr := r.URL.Query().Get("channel_id")
	accessHashStr := r.URL.Query().Get("access_hash")

	msgID, _ := strconv.Atoi(msgIDStr)
	channelID, _ := strconv.ParseInt(channelIDStr, 10, 64)
	accessHash, _ := strconv.ParseInt(accessHashStr, 10, 64)

	if err := ensureClientInitialized(); err != nil {
		http.Error(w, "client not initialized", 500)
		return
	}

	msg, err := getMsg(channelID, accessHash, int32(msgID))
	if err != nil {
		http.Error(w, "message not found: "+err.Error(), 404)
		return
	}

	doc := msg.Document()
	if doc == nil {
		http.Error(w, "no document", 404)
		return
	}

	totalSize := doc.Size
	mimeType := doc.MimeType

	w.Header().Set("Content-Type", mimeType)
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	rangeHeader := r.Header.Get("Range")
	start := int64(0)
	end := totalSize - 1

	if rangeHeader != "" {
		if strings.HasPrefix(rangeHeader, "bytes=") {
			parts := strings.Split(strings.TrimPrefix(rangeHeader, "bytes="), "-")
			if len(parts) >= 1 && parts[0] != "" {
				start, _ = strconv.ParseInt(parts[0], 10, 64)
			}
			if len(parts) >= 2 && parts[1] != "" {
				end, _ = strconv.ParseInt(parts[1], 10, 64)
			}
		}
		if end >= totalSize {
			end = totalSize - 1
		}
		if start > end || start >= totalSize {
			w.Header().Set("Content-Range", fmt.Sprintf("bytes */%d", totalSize))
			w.WriteHeader(http.StatusRequestedRangeNotSatisfiable)
			return
		}
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, totalSize))
		w.Header().Set("Content-Length", strconv.FormatInt(end-start+1, 10))
		w.WriteHeader(http.StatusPartialContent)
	} else {
		w.Header().Set("Content-Length", strconv.FormatInt(totalSize, 10))
		w.WriteHeader(http.StatusOK)
	}

	const chunkSize = 1048576 // 1MB - must match Telegram's chunk alignment

	ctx := r.Context()
	flusher, canFlush := w.(http.Flusher)

	// Prefetch the next chunk while writing the current one
	type fetchedChunk struct {
		data []byte
		err  error
	}

	prefetch := func(offset, fetchEnd int64) <-chan fetchedChunk {
		ch := make(chan fetchedChunk, 1)
		go func() {
			data, _, err := globalFetcher.client.DownloadChunk(msg, int(offset), int(fetchEnd), chunkSize)
			ch <- fetchedChunk{data: data, err: err}
		}()
		return ch
	}

	// Align start to chunk boundary
	alignedStart := (start / chunkSize) * chunkSize
	firstFetchEnd := alignedStart + chunkSize
	if firstFetchEnd > totalSize {
		firstFetchEnd = totalSize
	}

	// Start prefetching first chunk immediately
	nextChunkCh := prefetch(alignedStart, firstFetchEnd)
	nextChunkOffset := alignedStart

	for pos := alignedStart; pos <= end; {
		// Wait for prefetched chunk
		var fetched fetchedChunk
		select {
		case fetched = <-nextChunkCh:
		case <-ctx.Done():
			return
		}

		if fetched.err != nil {
			return
		}

		chunkData := fetched.data
		if len(chunkData) == 0 {
			return
		}

		// Prefetch next chunk immediately while we write this one
		nextChunkOffset = pos + chunkSize
		if nextChunkOffset <= end {
			nextFetchEnd := nextChunkOffset + chunkSize
			if nextFetchEnd > totalSize {
				nextFetchEnd = totalSize
			}
			nextChunkCh = prefetch(nextChunkOffset, nextFetchEnd)
		}

		// Trim to the requested range
		writeFrom := int64(0)
		if pos < start {
			writeFrom = start - pos
		}
		writeTo := int64(len(chunkData))
		if pos+writeTo > end+1 {
			writeTo = end + 1 - pos
		}

		if writeFrom < writeTo {
			_, err := w.Write(chunkData[writeFrom:writeTo])
			if err != nil {
				return
			}
			if canFlush {
				flusher.Flush()
			}
		}

		pos += chunkSize
	}
}

func main() {
}
