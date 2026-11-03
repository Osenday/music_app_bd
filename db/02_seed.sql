-- Datos iniciales: tablas A, B, C y D de Laura (Tarea 2), con sus identificadores originales.
-- El orden importa: primero las tablas referenciadas, después las que apuntan a ellas.
-- Transcripción: duración en segundos (2:45 → 165), sí/no → true/false, roles en minúsculas.

-- Países de artistas y suscriptores (tablas B y D).
INSERT INTO countries (country_code, country_name) VALUES
    ('US', 'Estados Unidos'),
    ('MX', 'México'),
    ('CO', 'Colombia'),
    ('AR', 'Argentina'),
    ('PR', 'Puerto Rico');

-- Supuesto: los subscription_id los asignamos nosotros; Laura no los trae.
-- Caso extra: 'Estudiante' es una suscripción sin suscriptores.
INSERT INTO subscriptions (subscription_id, subscription_type, price, has_ads) VALUES
    (1, 'Gratuita',     0, true),
    (2, 'Premium',    129, false),
    (3, 'Familiar',   199, false),
    (4, 'Estudiante',  69, false);

-- Tabla B. Caso existente: 108 no está en ningún álbum (tabla C).
INSERT INTO songs (song_id, title, duration_seconds, genre) VALUES
    (101, 'Ella Baila Sola',         165, 'Regional mexicano'),
    (102, 'TQG',                     197, 'Reguetón'),
    (103, 'Bzrp Music Sessions #53', 213, 'Pop latino'),
    (104, 'Flowers',                 200, 'Pop'),
    (105, 'Kill Bill',               153, 'R&B'),
    (106, 'Tití Me Preguntó',        243, 'Reguetón'),
    (107, 'Me Porto Bonito',         178, 'Reguetón'),
    (108, 'Calor de Agosto',         185, 'Regional mexicano');

-- Tabla D.
INSERT INTO subscribers (email, registered_at, subscription_id, country_code) VALUES
    ('ana@mail.com',   '2025-11-02', 2, 'MX'),
    ('luis@mail.com',  '2026-01-15', 1, 'MX'),
    ('marta@mail.com', '2026-05-20', 3, 'AR'),
    ('diego@mail.com', '2026-09-01', 3, 'MX');

-- Tabla B. Caso extra: A11 es un artista sin canciones ni álbumes.
INSERT INTO artists (artist_id, artist_name, country_code) VALUES
    ('A1',  'Karol G',            'CO'),
    ('A2',  'Shakira',            'CO'),
    ('A3',  'Miley Cyrus',        'US'),
    ('A4',  'SZA',                'US'),
    ('A5',  'Bizarrap',           'AR'),
    ('A6',  'Eslabon Armado',     'US'),
    ('A7',  'Peso Pluma',         'MX'),
    ('A8',  'Bad Bunny',          'PR'),
    ('A9',  'Chencho Corleone',   'PR'),
    ('A10', 'Los del Pitic',      'MX'),
    ('A11', 'Natalia Lafourcade', 'MX');

-- Tabla D: nombre_visible y foto. marta@mail.com no tiene foto.
INSERT INTO profiles (subscriber_email, display_name, photo) VALUES
    ('ana@mail.com',   'anaruiz', 'a1.jpg'),
    ('luis@mail.com',  'luis.s',  'l2.jpg'),
    ('marta@mail.com', 'marta_g', NULL),
    ('diego@mail.com', 'diegol',  'd4.jpg');

-- Supuesto: los library_id los asignamos nosotros. Todo suscriptor tiene biblioteca,
-- aunque esté vacía (marta@mail.com).
INSERT INTO libraries (library_id, subscriber_email) VALUES
    (1, 'ana@mail.com'),
    (2, 'luis@mail.com'),
    (3, 'marta@mail.com'),
    (4, 'diego@mail.com');

-- Tabla A. Caso existente: la playlist 13 está vacía.
INSERT INTO playlists (playlist_id, name, created_at, owner_email) VALUES
    (10, 'Gym',           '2026-03-01', 'ana@mail.com'),
    (11, 'Para estudiar', '2026-04-10', 'ana@mail.com'),
    (12, 'Gym',           '2026-05-02', 'luis@mail.com'),
    (13, 'Viaje',         '2026-06-15', 'marta@mail.com'),
    (14, 'Favoritas',     '2026-06-20', 'luis@mail.com');

-- Tabla C.
INSERT INTO albums (album_id, title, release_year, cover, artist_id) VALUES
    (201, 'Desvelado',                2023, 'desvelado.jpg', 'A6'),
    (202, 'Mañana Será Bonito',       2023, 'msb.jpg',       'A1'),
    (203, 'Endless Summer Vacation',  2023, 'esv.jpg',       'A3'),
    (204, 'SOS',                      2022, 'sos.jpg',       'A4'),
    (205, 'Un Verano Sin Ti',         2022, 'uvst.jpg',      'A8'),
    (206, 'Las Mujeres Ya No Lloran', 2024, 'lmynl.jpg',     'A2');

-- Tabla B: créditos de cada canción.
INSERT INTO song_artist (song_id, artist_id, role) VALUES
    (101, 'A6',  'principal'),
    (101, 'A7',  'feat.'),
    (102, 'A1',  'principal'),
    (102, 'A2',  'feat.'),
    (103, 'A5',  'principal'),
    (103, 'A2',  'feat.'),
    (104, 'A3',  'principal'),
    (105, 'A4',  'principal'),
    (106, 'A8',  'principal'),
    (107, 'A8',  'principal'),
    (107, 'A9',  'feat.'),
    (108, 'A10', 'principal');

-- Tabla C: pistas de cada álbum. 102 aparece en dos álbumes.
INSERT INTO song_album (album_id, song_id, track_number) VALUES
    (201, 101,  6),
    (202, 102,  6),
    (203, 104,  1),
    (204, 105,  2),
    (205, 107,  3),
    (205, 106,  4),
    (206, 103, 11),
    (206, 102, 12);

-- Tabla A: position es el orden de la canción en la celda de Laura.
INSERT INTO playlist_song (playlist_id, song_id, position, added_at) VALUES
    (10, 101, 1, '2026-03-01'),
    (10, 102, 2, '2026-03-01'),
    (10, 103, 3, '2026-03-04'),
    (11, 104, 1, '2026-04-10'),
    (11, 101, 2, '2026-04-12'),
    (12, 102, 1, '2026-05-02'),
    (12, 105, 2, '2026-05-02'),
    (14, 103, 1, '2026-06-20'),
    (14, 104, 2, '2026-06-21'),
    (14, 102, 3, '2026-06-22');

-- Tabla D: canciones_guardadas (library_id 1 = ana, 2 = luis, 4 = diego).
INSERT INTO library_song (library_id, song_id) VALUES
    (1, 102),
    (1, 104),
    (2, 103),
    (4, 101),
    (4, 108);

-- Tabla D: álbumes_guardados.
INSERT INTO library_album (library_id, album_id) VALUES
    (1, 205),
    (2, 204),
    (2, 206);
