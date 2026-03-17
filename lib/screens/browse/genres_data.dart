class Genre {
  final String id;
  final String label;
  final String? image;
  final String category;

  const Genre({
    required this.id,
    required this.label,
    this.image,
    required this.category,
  });
}

const Map<String, List<Genre>> genreSections = {
  'Popular Interests': [
    Genre(
        id: 'in0000001',
        label: "Action",
        image:
            "https://m.media-amazon.com/images/M/MV5BMDU4ZmM1NjYtNGY2MS00NmE1LThiMzAtNzU3NWZhYmM0ZjgxXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000034',
        label: "Comedy",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjU5NjQyNTcwOV5BMl5BanBnXkFtZTcwMzc3NzUyMw@@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000112',
        label: "Horror",
        image:
            "https://m.media-amazon.com/images/M/MV5BNThjMTAxN2QtOTkyMS00Y2EwLTgyMDctOWY2NTY0MzYzZjQ0XkEyXkFqcGc@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000222',
        label: "Hindi",
        image:
            "https://m.media-amazon.com/images/M/MV5BNjYwYzBhNjMtNzNmMC00NDhkLTgxYjAtZjkyNDA5OWJlOTNjXkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000209',
        label: "K-Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzk4MjRiYmUtNzkwMi00YWJiLTliMjktNDkyNzlmMjk4MThmXkEyXkFqcGc@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000206',
        label: "Shonen",
        image:
            "https://m.media-amazon.com/images/M/MV5BNmUyZWEzMzgtNDJhOS00NGZmLWFhYmQtN2I4YzQ0MTU3YmE4XkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
  ],
  'Action': [
    Genre(
        id: 'in0000001',
        label: "Action",
        image:
            "https://m.media-amazon.com/images/M/MV5BMDU4ZmM1NjYtNGY2MS00NmE1LThiMzAtNzU3NWZhYmM0ZjgxXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000002',
        label: "Action Epic",
        image:
            "https://m.media-amazon.com/images/M/MV5BM2RkNmFkZTItODFkMS00Yjk5LTg2YTQtMGQ0Zjc0Mzk3ZGQ5XkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000003',
        label: "B-Action",
        image:
            "https://m.media-amazon.com/images/M/MV5BNzMzNTI3MTg2NV5BMl5BanBnXkFtZTgwMTUwODU0NjM@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000004',
        label: "Car Action",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTQ2Nzg5ODU5NV5BMl5BanBnXkFtZTcwMDk2NTkxNA@@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000005',
        label: "Disaster",
        image:
            "https://m.media-amazon.com/images/M/MV5BODAzMDA4ZDYtNjJlNi00ZjlmLTk2ZTQtZTQ2NzI1ODg2M2ZjXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000006',
        label: "Martial Arts",
        image:
            "https://m.media-amazon.com/images/M/MV5BOGFmODI5ZWItZmIwZS00ZmQ5LThkOWUtZTY0OTU1ZmIwMmJlXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000008',
        label: "Superhero",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTM2MzY1ODc1Nl5BMl5BanBnXkFtZTcwNTg4OTY3Nw@@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000010',
        label: "War",
        image:
            "https://m.media-amazon.com/images/M/MV5BYTczMGFjOGUtZDJlMy00NWE2LWI5MGYtZWRkOThlZDllNjEwXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000197',
        label: "Gun Fu",
        image:
            "https://m.media-amazon.com/images/M/MV5BYmNhYjJiYTUtNWMyNy00NTUyLTlkZDktMDk2YTZiMTJhN2MxXkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000198',
        label: "Kung Fu",
        image:
            "https://m.media-amazon.com/images/M/MV5BNDkzNTkyODE1NF5BMl5BanBnXkFtZTgwNTE3MzYyNzE@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000199',
        label: "Samurai",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTg5MTc4MTc4M15BMl5BanBnXkFtZTcwNjA5MTU4Mw@@._V1_.jpg",
        category: "Action"),
    Genre(
        id: 'in0000200',
        label: "Wuxia",
        image:
            "https://m.media-amazon.com/images/M/MV5BMWJjMjgzYTctMTY5OC00YzQzLTk3MDMtMmY5YWNkYzFlMGU2XkEyXkFqcGc@._V1_.jpg",
        category: "Action"),
  ],
  'Adventure': [
    Genre(
        id: 'in0000012',
        label: "Adventure",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTlmNjQxNGItMmM1My00YTk2LTk2NjYtNTc4YWFjYTgxNTRiXkEyXkFqcGc@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000013',
        label: "Desert Adventure",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTM3MjcyNDMxMV5BMl5BanBnXkFtZTcwOTc0NTY0NQ@@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000014',
        label: "Dinosaur",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTQ1NzI2MzkyNl5BMl5BanBnXkFtZTgwMzcyOTIwMjE@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000015',
        label: "Adventure Epic",
        image:
            "https://m.media-amazon.com/images/M/MV5BNGE4NjIwMGYtYWQ4MC00NGIyLWI1YjQtNjJmZjllYjFjMDgzXkEyXkFqcGc@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000017',
        label: "Jungle",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzQ5OTUwOTQ4M15BMl5BanBnXkFtZTgwNzEyODQ0MzI@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000018',
        label: "Mountain",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjEwMTIwOTQ0NV5BMl5BanBnXkFtZTgwNzkxODk4NTE@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000019',
        label: "Quest",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTg2MTIzMTIwNV5BMl5BanBnXkFtZTcwNDM5NTkxNA@@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000020',
        label: "Road Trip",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjMzOTI0MTA1OF5BMl5BanBnXkFtZTgwNjM4Nzk5OTE@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000021',
        label: "Sea Adventure",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTM0NDI4MDEyN15BMl5BanBnXkFtZTcwNTYyMTI3Nw@@._V1_.jpg",
        category: "Adventure"),
    Genre(
        id: 'in0000022',
        label: "Swashbuckler",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTAzNTY1NjYwMl5BMl5BanBnXkFtZTgwNTIwNjMzMjI@._V1_.jpg",
        category: "Adventure"),
  ],
  'Animation': [
    Genre(
        id: 'in0000026',
        label: "Animation",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzI1NDk0MzEzN15BMl5BanBnXkFtZTcwOTE0MjIyNw@@._V1_.jpg",
        category: "Animation"),
    Genre(
        id: 'in0000027',
        label: "Anime",
        image:
            "https://m.media-amazon.com/images/M/MV5BMGYzOTdhY2EtZjYwYi00ZjhmLWIwNjQtZjc1OWNmODcyOWMzXkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
    Genre(
        id: 'in0000025',
        label: "Adult Animation",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjQwMzc3ODM4OV5BMl5BanBnXkFtZTgwMTE0MTUxMDI@._V1_.jpg",
        category: "Animation"),
    Genre(
        id: 'in0000028',
        label: "Computer Animation",
        image:
            "https://m.media-amazon.com/images/M/MV5BYTBhNGUyNTktYTlhYy00MzNkLThkMmQtYTZiNTNhZTMzYjcyXkEyXkFqcGc@._V1_.jpg",
        category: "Animation"),
    Genre(
        id: 'in0000201',
        label: "Isekai",
        image:
            "https://m.media-amazon.com/images/M/MV5BNTkzOTMzOTktMWFlYS00Nzk3LTk2MDktNjZjNThiY2IzNWNlXkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
    Genre(
        id: 'in0000206',
        label: "Shonen",
        image:
            "https://m.media-amazon.com/images/M/MV5BNmUyZWEzMzgtNDJhOS00NGZmLWFhYmQtN2I4YzQ0MTU3YmE4XkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
    Genre(
        id: 'in0000207',
        label: "Shojo",
        image:
            "https://m.media-amazon.com/images/M/MV5BZmM5OTc3OGMtNzFmZi00YzI2LTkzNWEtMTc4NWY5Y2YxYzY5XkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
    Genre(
        id: 'in0000204',
        label: "Mecha",
        image:
            "https://m.media-amazon.com/images/M/MV5BZWNkMTc2YzQtMWE1My00NGRiLTgzYzItOTQyYzc3NTE0YjViXkEyXkFqcGc@._V1_.jpg",
        category: "Anime"),
  ],
  'Comedy': [
    Genre(
        id: 'in0000034',
        label: "Comedy",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjU5NjQyNTcwOV5BMl5BanBnXkFtZTcwMzc3NzUyMw@@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000031',
        label: "Body Swap",
        image:
            "https://m.media-amazon.com/images/M/MV5BOGFjMzk3MDAtM2YyNS00NGE2LTk0Y2EtZjZmNjE4NmI3Mzk3XkEyXkFqcGc@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000032',
        label: "Buddy Comedy",
        image:
            "https://m.media-amazon.com/images/M/MV5BOWY4MTM1M2QtZWIwMi00MWRkLWFhNDItOWI5MjA3ZWQyNTgwXkEyXkFqcGc@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000033',
        label: "Buddy Cop",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjE0MTE1MTk5MV5BMl5BanBnXkFtZTcwMjY1MTkxNA@@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000035',
        label: "Dark Comedy",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTkxOTA2OTgzM15BMl5BanBnXkFtZTgwOTgzMzI5NzM@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000038',
        label: "Mockumentary",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjQxNDM4ODE0OV5BMl5BanBnXkFtZTgwNjk4Mjk4MzI@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000039',
        label: "Parody",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTY4NDI0NzcwOF5BMl5BanBnXkFtZTcwOTY0MjI3NA@@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000042',
        label: "Satire",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjYwNDQ1YzgtY2ZjYS00YjNmLTk0MjktMGY0YzNjMjQ4NGQ2XkEyXkFqcGc@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000047',
        label: "Stand-Up",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjUyNDQ0NDMwMV5BMl5BanBnXkFtZTgwNzg3MjA0NTM@._V1_.jpg",
        category: "Comedy"),
    Genre(
        id: 'in0000049',
        label: "Teen Comedy",
        image:
            "https://m.media-amazon.com/images/M/MV5BYWUwNTZhODQtZWMxNi00YTBjLWE4NTctZjNkMjc5NzA4ZDdlXkEyXkFqcGc@._V1_.jpg",
        category: "Comedy"),
  ],
  'Crime': [
    Genre(
        id: 'in0000052',
        label: "Crime",
        image:
            "https://m.media-amazon.com/images/M/MV5BY2M4MTFlOWMtYzhiYS00OGI3LTg0ODItODk3ODVjMzIyMmMyXkEyXkFqcGc@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000050',
        label: "Caper",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjAwODUyNjc2MF5BMl5BanBnXkFtZTcwMDM5OTQyNw@@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000051',
        label: "Cop Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BNDYxNDY5MTI4NV5BMl5BanBnXkFtZTgwMTQ0MzMzMTI@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000054',
        label: "Film Noir",
        image:
            "https://m.media-amazon.com/images/M/MV5BODQ0Mjc4NTktMTUwZS00M2E5LWI3YjYtMzA3YzA4MjYxYTFjXkEyXkFqcGc@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000055',
        label: "Gangster",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTFhMzgwNzQtNTYzMS00NDdlLWJkMjYtMGY3ZGY5NjZjYjliXkEyXkFqcGc@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000056',
        label: "Heist",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTc1NDg5MTMzOV5BMl5BanBnXkFtZTcwNjEzNzIwNA@@._V1_.jpg",
        category: "Crime"),
    Genre(
        id: 'in0000058',
        label: "True Crime",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTMxNjA5MzkzN15BMl5BanBnXkFtZTcwNjU5NDIyMw@@._V1_.jpg",
        category: "Crime"),
  ],
  'Documentary': [
    Genre(
        id: 'in0000060',
        label: "Documentary",
        image:
            "https://m.media-amazon.com/images/M/MV5BMmJiY2IzZGItMzA4Ni00OWVkLWJjZGUtZDYzNDllNjY4OGEwXkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
    Genre(
        id: 'in0000061',
        label: "Docuseries",
        image:
            "https://m.media-amazon.com/images/M/MV5BODQyNjQwYjYtNmM1My00YjhjLWI3Y2EtMWJlMjUzOWM2OWJkXkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
    Genre(
        id: 'in0000064',
        label: "History",
        image:
            "https://m.media-amazon.com/images/M/MV5BYmQ4OTAwNmQtNmI3MS00NDhkLTk0Y2QtZWViM2ZiMjUxYjA0XkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
    Genre(
        id: 'in0000067',
        label: "Nature",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTcyZjVhY2QtOTUwOS00MGU0LWI0NzctMWFjYzU2MTUyYjQ1XkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
    Genre(
        id: 'in0000070',
        label: "Sports",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTc3ZTgzMWEtN2E4NS00MjQxLThjZTktYjY2Zjc5ZTgxZjc1XkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
    Genre(
        id: 'in0000059',
        label: "Crime Doc",
        image:
            "https://m.media-amazon.com/images/M/MV5BNzQ3MWE5Y2QtOTM5Ny00MjM0LWJmMGUtZTczZjY0M2VjMzZlXkEyXkFqcGc@._V1_.jpg",
        category: "Documentary"),
  ],
  'Drama': [
    Genre(
        id: 'in0000076',
        label: "Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BN2MxZmYzMDItYzNkMS00YWY1LWIzNDktNTI3YTQxMGNjZjEzXkEyXkFqcGc@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000072',
        label: "Biography",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzI3NTUyNTg0NF5BMl5BanBnXkFtZTcwNTk2NDcwNw@@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000073',
        label: "Coming-of-Age",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjIzMjE3MTI1NF5BMl5BanBnXkFtZTgwNzE3MTgyNDM@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000081',
        label: "Legal Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTU0Njk2ODM4OF5BMl5BanBnXkFtZTgwODUxOTIwMjE@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000082',
        label: "Medical Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTAxOTQxNTIwMDZeQTJeQWpwZ15BbWU4MDI2MDg2ODAy._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000209',
        label: "Korean Drama",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzk4MjRiYmUtNzkwMi00YWJiLTliMjktNDkyNzlmMjk4MThmXkEyXkFqcGc@._V1_.jpg",
        category: "Drama"),
    Genre(
        id: 'in0000210',
        label: "Telenovela",
        image:
            "https://m.media-amazon.com/images/M/MV5BZjM1ZTZjMDQtNzgxMi00MjNmLTk2ZmQtODA1ZTE0ZjYyMTYxXkEyXkFqcGc@._V1_.jpg",
        category: "Drama"),
  ],
  'Family': [
    Genre(
        id: 'in0000093',
        label: "Family",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTA1OTcyMzQ0MTBeQTJeQWpwZ15BbWU4MDIwNzE4OTEx._V1_.jpg",
        category: "Family"),
    Genre(
        id: 'in0000092',
        label: "Animal Adventure",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTQ5MTgyODg0NF5BMl5BanBnXkFtZTgwOTg2MTEwNDE@._V1_.jpg",
        category: "Family"),
  ],
  'Fantasy': [
    Genre(
        id: 'in0000098',
        label: "Fantasy",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTc5NTU2NDQ5Ml5BMl5BanBnXkFtZTcwMDIxMjk2Mw@@._V1_.jpg",
        category: "Fantasy"),
    Genre(
        id: 'in0000095',
        label: "Dark Fantasy",
        image:
            "https://m.media-amazon.com/images/M/MV5BZjdhOTYwZTktNzUwOS00MWJiLWI0ZDgtN2ZhNzhlZTUzNmM4XkEyXkFqcGc@._V1_.jpg",
        category: "Fantasy"),
    Genre(
        id: 'in0000097',
        label: "Fairy Tale",
        image:
            "https://m.media-amazon.com/images/M/MV5BMWQ3NjU5NjMtY2ZhNy00ODU3LTlkNjAtMGE5ZDBkYmZlODIxXkEyXkFqcGc@._V1_.jpg",
        category: "Fantasy"),
    Genre(
        id: 'in0000100',
        label: "Sword & Sorcery",
        image:
            "https://m.media-amazon.com/images/M/MV5BM2JkN2M5YjQtNTcwMC00NGU2LWE3MTAtYTQ4ZTRmZDljZGRiXkEyXkFqcGc@._V1_.jpg",
        category: "Fantasy"),
  ],
  'Game Show': [
    Genre(
        id: 'in0000105',
        label: "Game Show",
        image:
            "https://m.media-amazon.com/images/M/MV5BOGJmMzdiNTktNzJmYi00MjMxLTk0YjItNmZkMWVkYmNjNzE1XkEyXkFqcGc@._V1_.jpg",
        category: "Game Show"),
    Genre(
        id: 'in0000102',
        label: "Beauty Competition",
        image:
            "https://m.media-amazon.com/images/M/MV5BZDVlNjYwMjctNGUzOC00NTdiLTllY2QtYjExOWY0NjAzYmUyXkEyXkFqcGc@._V1_.jpg",
        category: "Game Show"),
    Genre(
        id: 'in0000103',
        label: "Cooking Competition",
        image:
            "https://m.media-amazon.com/images/M/MV5BZjA1NDhiOGItZDY2Yi00ZjNmLWJmZjItMTZkNWRjYjM4ZDhhXkEyXkFqcGc@._V1_.jpg",
        category: "Game Show"),
    Genre(
        id: 'in0000106',
        label: "Survival Competition",
        image:
            "https://m.media-amazon.com/images/M/MV5BNjcyYTc1NTctOTQwMi00OGE5LTg2ZWMtYjQwZGIyMmFhMGE4XkEyXkFqcGc@._V1_.jpg",
        category: "Game Show"),
  ],
  'Horror': [
    Genre(
        id: 'in0000112',
        label: "Horror",
        image:
            "https://m.media-amazon.com/images/M/MV5BNThjMTAxN2QtOTkyMS00Y2EwLTgyMDctOWY2NTY0MzYzZjQ0XkEyXkFqcGc@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000109',
        label: "Body Horror",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjA0NDE0NDM1Ml5BMl5BanBnXkFtZTgwMzk0ODIwMjE@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000114',
        label: "Psychological",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTUxMjEzNzE1NF5BMl5BanBnXkFtZTgwNDYwNjUzMTI@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000115',
        label: "Slasher",
        image:
            "https://m.media-amazon.com/images/M/MV5BZTQ1MmFmYmUtNWI4YS00YjJhLTk0YzgtZGM4ODQ4N2ZkYTAzXkEyXkFqcGc@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000117',
        label: "Supernatural",
        image:
            "https://m.media-amazon.com/images/M/MV5BNWEwY2NjZjItMzA5Zi00ZDU0LTljOWItOGZiODJhMGE5MTIyXkEyXkFqcGc@._V1_.jpg",
        category: "Horror"),
    Genre(
        id: 'in0000122',
        label: "Zombie",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTJjZWE5NzYtYjEyNC00ZDUyLTgxMTAtNDgyOWUzZWExMzUwXkEyXkFqcGc@._V1_.jpg",
        category: "Horror"),
  ],
  'Language': [
    Genre(
        id: 'in0000222',
        label: "Hindi",
        image:
            "https://m.media-amazon.com/images/M/MV5BNjYwYzBhNjMtNzNmMC00NDhkLTgxYjAtZjkyNDA5OWJlOTNjXkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000240',
        label: "Malayalam",
        image:
            "https://m.media-amazon.com/images/M/MV5BYTA4Yjg0NGUtOTNmMS00YzdiLWEwNzAtNWFlZjIwZDYwZDM2XkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000235',
        label: "Tamil",
        image:
            "https://m.media-amazon.com/images/M/MV5BZTRmZjFmNWItNzM0ZS00YjJlLWI1YjktM2YyZjZjZTJiMmIwXkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000236',
        label: "Telugu",
        image:
            "https://m.media-amazon.com/images/M/MV5BODgzMGYyYjAtMmRhNi00ZGM4LTkwOTMtNzAzM2Q5MjM1MzZjXkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000241',
        label: "Kannada",
        image:
            "https://m.media-amazon.com/images/M/MV5BNTQ5OTYzZGMtYjAxMC00M2ViLTk3N2YtNDQyNWJmZDkxOWRlXkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000219',
        label: "French",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzYzNDg5MTY5Ml5BMl5BanBnXkFtZTgwNzA2ODk5MTE@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000224',
        label: "Japanese",
        image:
            "https://m.media-amazon.com/images/M/MV5BNGI1MThmNWQtYjM4NC00NTg1LWE5Y2EtM2M4MDVhMDk4MTk2XkEyXkFqcGc@._V1_.jpg",
        category: "Language"),
    Genre(
        id: 'in0000225',
        label: "Korean",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTMyNzQxMjc3OF5BMl5BanBnXkFtZTcwNjQ4MTI2NQ@@._V1_.jpg",
        category: "Language"),
  ],
  'Lifestyle': [
    Genre(
        id: 'in0000126',
        label: "Lifestyle",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjE1NzkzNjU0MF5BMl5BanBnXkFtZTgwNzM0MjQ5NjM@._V1_.jpg",
        category: "Lifestyle"),
    Genre(
        id: 'in0000124',
        label: "Cooking",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTU4MTUxNjU3MV5BMl5BanBnXkFtZTgwMTU5MzQxNjM@._V1_.jpg",
        category: "Lifestyle"),
    Genre(
        id: 'in0000128',
        label: "Travel",
        image:
            "https://m.media-amazon.com/images/M/MV5BYzA2ZjkxNzItMzE5Ni00OWQzLTlkM2MtZWRiMmRiYWNmYTU2XkEyXkFqcGc@._V1_.jpg",
        category: "Lifestyle"),
    Genre(
        id: 'in0000127',
        label: "Talk Show",
        image:
            "https://m.media-amazon.com/images/M/MV5BM2IxOGRhN2UtMGZiMC00OGI1LWE5NzktOGYxMTU5YzEwMTk3XkEyXkFqcGc@._V1_.jpg",
        category: "Lifestyle"),
  ],
  'Music': [
    Genre(
        id: 'in0000130',
        label: "Music",
        image:
            "https://m.media-amazon.com/images/M/MV5BNzJjNGEzMGMtOGEyZi00MjNkLWIyMjgtMDc0MmMwZGYzZGM0XkEyXkFqcGc@._V1_.jpg",
        category: "Music"),
    Genre(
        id: 'in0000129',
        label: "Concert",
        image:
            "https://m.media-amazon.com/images/M/MV5BZWY3MGRkNWItYThlMS00MWVhLWEyOGEtOWUzYTI0Y2I4NTkzXkEyXkFqcGc@._V1_.jpg",
        category: "Music"),
  ],
  'Musical': [
    Genre(
        id: 'in0000133',
        label: "Musical",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjEyNDc2MDMyNV5BMl5BanBnXkFtZTcwNDU0MTUzNA@@._V1_.jpg",
        category: "Musical"),
    Genre(
        id: 'in0000131',
        label: "Classic Musical",
        image:
            "https://m.media-amazon.com/images/M/MV5BZTI4MjcyOTItYzVlZS00NTc4LWEyYzktNTFlYTRmNTIzYzE5XkEyXkFqcGc@._V1_.jpg",
        category: "Musical"),
  ],
  'Mystery': [
    Genre(
        id: 'in0000139',
        label: "Mystery",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzBiMjliOWUtYjBhNC00NWI1LWEzMzYtMjZmZTY4YmM1MzQwXkEyXkFqcGc@._V1_.jpg",
        category: "Mystery"),
    Genre(
        id: 'in0000141',
        label: "Whodunnit",
        image:
            "https://m.media-amazon.com/images/M/MV5BNjQ0OTc2NjY4MF5BMl5BanBnXkFtZTcwMjM5MTExNw@@._V1_.jpg",
        category: "Mystery"),
  ],
  'Reality TV': [
    Genre(
        id: 'in0000148',
        label: "Reality TV",
        image:
            "https://m.media-amazon.com/images/M/MV5BZGE5NzkzZWQtODQyMC00N2Q0LTk0MGEtY2ExM2ZiZDQ2MTdhXkEyXkFqcGc@._V1_.jpg",
        category: "Reality TV"),
    Genre(
        id: 'in0000144',
        label: "Dating Reality",
        image:
            "https://m.media-amazon.com/images/M/MV5BNDQ1NTFhYzAtY2FkOS00MDIzLWFmMzYtMzAzYjQyMzg3MTFlXkEyXkFqcGc@._V1_.jpg",
        category: "Reality TV"),
    Genre(
        id: 'in0000146',
        label: "Hidden Camera",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTFiNTQ3OGMtYTYzZC00OWQ5LWEzMmYtOGU5NDk1YWIzNWNlXkEyXkFqcGc@._V1_.jpg",
        category: "Reality TV"),
  ],
  'Romance': [
    Genre(
        id: 'in0000152',
        label: "Romance",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTc0MzYxMTQ1M15BMl5BanBnXkFtZTgwOTk0MTI2NDM@._V1_.jpg",
        category: "Romance"),
    Genre(
        id: 'in0000153',
        label: "Rom-Com",
        image:
            "https://m.media-amazon.com/images/M/MV5BY2I1MTE5OWMtNzY0My00YTg0LWE5ODEtNTg5NDMzNDFkNzNiXkEyXkFqcGc@._V1_.jpg",
        category: "Romance"),
    Genre(
        id: 'in0000151',
        label: "Feel-Good",
        image:
            "https://m.media-amazon.com/images/M/MV5BM2RmYmUyODktNDNhOC00YTBjLTg3ZDktYjZiOTYzOTI3MTRjXkEyXkFqcGc@._V1_.jpg",
        category: "Romance"),
    Genre(
        id: 'in0000155',
        label: "Teen Romance",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTMxNjAxOTE3MF5BMl5BanBnXkFtZTcwMDAwOTQzNA@@._V1_.jpg",
        category: "Romance"),
  ],
  'Sci-Fi': [
    Genre(
        id: 'in0000162',
        label: "Sci-Fi",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTkxMzc0MDg5MV5BMl5BanBnXkFtZTcwNjUxMzA4NA@@._V1_.jpg",
        category: "Sci-Fi"),
    Genre(
        id: 'in0000158',
        label: "A.I.",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTk4MTc1NDczNV5BMl5BanBnXkFtZTgwODAwNTAwNDE@._V1_.jpg",
        category: "Sci-Fi"),
    Genre(
        id: 'in0000159',
        label: "Cyberpunk",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTAzMzZiZjAtMzJhMy00ZDNkLWFmZGEtODc5ODcwMTBkYzQyXkEyXkFqcGc@._V1_.jpg",
        category: "Sci-Fi"),
    Genre(
        id: 'in0000160',
        label: "Dystopian",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTg4MDEyODA0NF5BMl5BanBnXkFtZTgwMzUxNDE2MzI@._V1_.jpg",
        category: "Sci-Fi"),
    Genre(
        id: 'in0000164',
        label: "Space",
        image:
            "https://m.media-amazon.com/images/M/MV5BOTY2NjMzNDk3NV5BMl5BanBnXkFtZTgwODI5Nzg0OTE@._V1_.jpg",
        category: "Sci-Fi"),
    Genre(
        id: 'in0000166',
        label: "Time Travel",
        image:
            "https://m.media-amazon.com/images/M/MV5BY2YzZjcwNjktMTIyNi00Nzg0LWEyMDctOTdiZDZmOTEzOTQ2XkEyXkFqcGc@._V1_.jpg",
        category: "Sci-Fi"),
  ],
  'Seasonal': [
    Genre(
        id: 'in0000192',
        label: "Holiday",
        image:
            "https://m.media-amazon.com/images/M/MV5BZTY4YjY3MjctZjczZS00ZjAzLWE3NmMtNjY4YjQyYmEyOGRjXkEyXkFqcGc@._V1_.jpg",
        category: "Seasonal"),
    Genre(
        id: 'in0000193',
        label: "Holiday Animation",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzg3YjA4MzQtM2ZlNS00ZjMyLTg0OWItNmFmMWIwZTE3ZTljXkEyXkFqcGc@._V1_.jpg",
        category: "Seasonal"),
    Genre(
        id: 'in0000196',
        label: "Holiday Romance",
        image:
            "https://m.media-amazon.com/images/M/MV5BNTM5YjZkMzYtNGE0MC00MTk4LTlkMmEtMDcyMzA1MWUxMzVmXkEyXkFqcGc@._V1_.jpg",
        category: "Seasonal"),
  ],
  'Short': [
    Genre(
        id: 'in0000212',
        label: "Short",
        image:
            "https://m.media-amazon.com/images/M/MV5BNGFlMTVhZTQtNWU5Ny00YTRlLThjODYtNWMwYjRjYzA1Y2RlXkEyXkFqcGc@._V1_.jpg",
        category: "Short"),
  ],
  'Sport': [
    Genre(
        id: 'in0000174',
        label: "Sport",
        image:
            "https://m.media-amazon.com/images/M/MV5BMjAwNDMyNzEwMF5BMl5BanBnXkFtZTcwNDA4MjkwNg@@._V1_.jpg",
        category: "Sport"),
    Genre(
        id: 'in0000168',
        label: "Basketball",
        image:
            "https://m.media-amazon.com/images/M/MV5BNDFiZGRiNDYtNzJlYS00NTMzLTk4MWUtNjU3MGM2ZWRjNTJmXkEyXkFqcGc@._V1_.jpg",
        category: "Sport"),
    Genre(
        id: 'in0000169',
        label: "Boxing",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTUzNDIxOTc0MV5BMl5BanBnXkFtZTcwNTQ3NTMyNA@@._V1_.jpg",
        category: "Sport"),
    Genre(
        id: 'in0000171',
        label: "Football",
        image:
            "https://m.media-amazon.com/images/M/MV5BMTk0ODgzNDc4MV5BMl5BanBnXkFtZTgwNzc5OTIwMjE@._V1_.jpg",
        category: "Sport"),
    Genre(
        id: 'in0000173',
        label: "Soccer",
        image:
            "https://m.media-amazon.com/images/M/MV5BOGZlM2EzMjQtZWJmZS00MTJmLWJmZGMtYjVlNTdhMTk3ZWViXkEyXkFqcGc@._V1_.jpg",
        category: "Sport"),
  ],
  'Thriller': [
    Genre(
        id: 'in0000186',
        label: "Thriller",
        image:
            "https://m.media-amazon.com/images/M/MV5BMWM3ZjRhMDQtZDUzYi00NWY0LThhMDQtZTM2MjZmNjRlMTRmXkEyXkFqcGc@._V1_.jpg",
        category: "Thriller"),
    Genre(
        id: 'in0000182',
        label: "Psychological",
        image:
            "https://m.media-amazon.com/images/M/MV5BN2I4MDk2ODQtZjU3YS00Zjk5LThlNDMtYjljNjY4NzdjODBkXkEyXkFqcGc@._V1_.jpg",
        category: "Thriller"),
    Genre(
        id: 'in0000184',
        label: "Spy",
        image:
            "https://m.media-amazon.com/images/M/MV5BNDk5Njk4ODM5Nl5BMl5BanBnXkFtZTcwMjEzNzc3Nw@@._V1_.jpg",
        category: "Thriller"),
    Genre(
        id: 'in0000185',
        label: "Survival",
        image:
            "https://m.media-amazon.com/images/M/MV5BYTY2Nzk5MWMtMmNlOC00MDA2LWJmZGYtNmQxNGIyZGIyMjQ1XkEyXkFqcGc@._V1_.jpg",
        category: "Thriller"),
  ],
  'Western': [
    Genre(
        id: 'in0000191',
        label: "Western",
        image:
            "https://m.media-amazon.com/images/M/MV5BODUxNTQ4MmMtNTIyZC00MzRlLTlhZTItMzc0NDdmMmVhMjc4XkEyXkFqcGc@._V1_.jpg",
        category: "Western"),
    Genre(
        id: 'in0000190',
        label: "Spaghetti Western",
        image:
            "https://m.media-amazon.com/images/M/MV5BMzE4ODY3MjAtZjM0OS00YzIxLWEyZTUtNTk2MTBiMGIwMTRlXkEyXkFqcGc@._V1_.jpg",
        category: "Western"),
  ],
};
