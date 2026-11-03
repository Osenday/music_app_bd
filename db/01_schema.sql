-- Esquema de la BD de Spotify.
-- El orden importa: una tabla debe existir antes de que otra haga referencia a ella.
-- Nombres según la convención de la Tarea 2: entidades en inglés y plural,
-- tablas de unión con el singular de ambas entidades, atributos en snake_case.

-- ---------------------------------------------------------------------
-- Nivel 0: tablas que no apuntan a ninguna otra
-- ---------------------------------------------------------------------

-- Entidad nueva surgida al normalizar (pais_clave → pais_nombre era transitiva).
-- Llave natural: el código ISO de 2 letras es estable y hace más legibles las consultas.
CREATE TABLE countries (
    country_code char(2)      PRIMARY KEY CHECK (country_code ~ '^[A-Z]{2}$'),
    country_name varchar(100) NOT NULL UNIQUE
);

-- Llave sustituta: el nombre del tipo puede cambiar ("Gratuita" → "Free") y no usamos
-- ON UPDATE CASCADE. El nombre sigue sin poder repetirse: UNIQUE.
-- Supuesto: los subscription_id los asignamos nosotros; Laura no los trae.
CREATE TABLE subscriptions (
    subscription_id   integer      PRIMARY KEY,
    subscription_type varchar(50)  NOT NULL UNIQUE,
    price             numeric(6,2) NOT NULL CHECK (price >= 0),  -- MXN al mes; la Gratuita cuesta 0
    has_ads           boolean      NOT NULL
);

-- La duración se guarda en segundos: el tipo time interpretaría '2:45' como 2 horas 45 minutos.
CREATE TABLE songs (
    song_id          integer      PRIMARY KEY,
    title            varchar(200) NOT NULL,
    duration_seconds integer      NOT NULL CHECK (duration_seconds > 0),
    genre            varchar(50)  NOT NULL
);

-- ---------------------------------------------------------------------
-- Nivel 1
-- ---------------------------------------------------------------------

-- subscriptions (1..1) — subscribers (0..N): NOT NULL en subscription_id da el
-- "exactamente una suscripción". El 0..N no requiere restricción: una suscripción
-- a la que ningún suscriptor apunta es válida.
-- countries (1..1) — subscribers (0..N): todo suscriptor tiene país.
-- Supuesto: el email identifica al suscriptor y no cambia (no hay ON UPDATE CASCADE).
CREATE TABLE subscribers (
    email           varchar(255) PRIMARY KEY CHECK (email LIKE '_%@_%'),
    registered_at   date         NOT NULL,
    subscription_id integer      NOT NULL REFERENCES subscriptions (subscription_id),
    country_code    char(2)      NOT NULL REFERENCES countries (country_code)
);

-- countries (1..1) — artists (0..N): todo artista tiene país; un país puede no tener artistas.
-- Llave natural: Laura ya identifica a los artistas como 'A1', 'A2', ...
CREATE TABLE artists (
    artist_id    varchar(10)  PRIMARY KEY,
    artist_name  varchar(100) NOT NULL,
    country_code char(2)      NOT NULL REFERENCES countries (country_code)
);

-- ---------------------------------------------------------------------
-- Nivel 2
-- ---------------------------------------------------------------------

-- subscribers (1..1) — profiles (1..1). Entidad separada del suscriptor (diagrama conceptual).
-- La PK es también la FK: NOT NULL da el mínimo de 1 suscriptor por perfil y la PK
-- (que implica UNIQUE) da el máximo de 1 perfil por suscriptor.
-- El mínimo de 1 perfil por suscriptor no se puede forzar con una FK: lo garantiza
-- la transacción de registro (tests.sql).
CREATE TABLE profiles (
    subscriber_email varchar(255) PRIMARY KEY REFERENCES subscribers (email),
    display_name     varchar(50)  NOT NULL,
    photo            varchar(255)              -- puede faltar (marta@mail.com no tiene foto)
);

-- subscribers (1..1) — libraries (1..1). Lleva llave propia porque library_song y
-- library_album cuelgan de ella. UNIQUE + NOT NULL en subscriber_email hacen el 1..1
-- de este lado; el mínimo de 1 biblioteca por suscriptor lo garantiza la transacción.
-- Supuesto: los library_id los asignamos nosotros.
CREATE TABLE libraries (
    library_id       integer      PRIMARY KEY,
    subscriber_email varchar(255) NOT NULL UNIQUE REFERENCES subscribers (email)
);

-- subscribers (1..1) — playlists (0..N): toda playlist tiene exactamente un dueño;
-- un suscriptor puede no tener playlists (diego@mail.com).
-- El nombre no es UNIQUE: ana y luis tienen cada uno una playlist "Gym".
CREATE TABLE playlists (
    playlist_id integer      PRIMARY KEY,
    name        varchar(100) NOT NULL,
    created_at  date         NOT NULL,
    owner_email varchar(255) NOT NULL REFERENCES subscribers (email)
);

-- artists (1..1) — albums (0..N): todo álbum tiene un artista; un artista puede no
-- tener álbumes (Peso Pluma, Bizarrap...).
CREATE TABLE albums (
    album_id     integer      PRIMARY KEY,
    title        varchar(200) NOT NULL,
    release_year integer      NOT NULL CHECK (release_year BETWEEN 1900 AND 2100),
    cover        varchar(255) NOT NULL,
    artist_id    varchar(10)  NOT NULL REFERENCES artists (artist_id)
);

-- Tabla de unión: la llave primaria es compuesta y cada una de sus columnas es FK.
-- songs (1..1) — song_artist (1..N): el mínimo de 1 artista por canción no se puede
-- forzar con una FK: es un supuesto documentado.
-- artists (1..1) — song_artist (0..N): un artista puede no tener canciones.
CREATE TABLE song_artist (
    song_id   integer     NOT NULL REFERENCES songs (song_id),
    artist_id varchar(10) NOT NULL REFERENCES artists (artist_id),
    role      varchar(10) NOT NULL CHECK (role IN ('principal', 'feat.')),
    PRIMARY KEY (song_id, artist_id)
);

-- Toda canción tiene a lo más un artista principal (UNIQUE parcial).
CREATE UNIQUE INDEX song_artist_one_principal
    ON song_artist (song_id) WHERE role = 'principal';

-- ---------------------------------------------------------------------
-- Nivel 3
-- ---------------------------------------------------------------------

-- albums (1..1) — song_album (1..N): el mínimo de 1 canción por álbum es un supuesto.
-- songs (1..1) — song_album (0..N): una canción puede no estar en ningún álbum (108)
-- o estar en varios (102 está en 202 y 206).
-- Dos canciones no pueden ocupar la misma pista de un álbum: UNIQUE (album_id, track_number).
CREATE TABLE song_album (
    album_id     integer NOT NULL REFERENCES albums (album_id),
    song_id      integer NOT NULL REFERENCES songs (song_id),
    track_number integer NOT NULL CHECK (track_number > 0),
    PRIMARY KEY (album_id, song_id),
    UNIQUE (album_id, track_number)
);

-- playlists (1..1) — playlist_song (0..N): una playlist puede estar vacía (13).
-- songs (1..1) — playlist_song (0..N): una canción puede no estar en ninguna playlist.
-- Supuesto: una canción no se repite dentro de una playlist (PK compuesta).
-- position es el orden en la playlist (el orden de la celda en la tabla A de Laura);
-- dos canciones no pueden ocupar la misma posición: UNIQUE (playlist_id, position).
CREATE TABLE playlist_song (
    playlist_id integer NOT NULL REFERENCES playlists (playlist_id),
    song_id     integer NOT NULL REFERENCES songs (song_id),
    position    integer NOT NULL CHECK (position > 0),
    added_at    date    NOT NULL,
    PRIMARY KEY (playlist_id, song_id),
    UNIQUE (playlist_id, position)
);

-- libraries (1..1) — library_song (0..N): una biblioteca puede estar vacía (marta).
-- songs (1..1) — library_song (0..N). Una canción se guarda una sola vez por biblioteca.
CREATE TABLE library_song (
    library_id integer NOT NULL REFERENCES libraries (library_id),
    song_id    integer NOT NULL REFERENCES songs (song_id),
    PRIMARY KEY (library_id, song_id)
);

-- libraries (1..1) — library_album (0..N); albums (1..1) — library_album (0..N).
CREATE TABLE library_album (
    library_id integer NOT NULL REFERENCES libraries (library_id),
    album_id   integer NOT NULL REFERENCES albums (album_id),
    PRIMARY KEY (library_id, album_id)
);
