-- Pruebas de la BD de Spotify.
-- Cada comentario dice qué resultado esperar.
-- Se puede ejecutar más de una vez con el mismo resultado: los casos que fallan no cambian nada,
-- y el suscriptor que se registra en c) se elimina al final de c).
-- (Si una ejecución se interrumpe a la mitad, sofia@mail.com puede quedar registrada;
-- en ese caso, reinicia con docker compose down -v y docker compose up -d.)

-- ---------------------------------------------------------------------
-- a) Las preguntas de Laura
-- ---------------------------------------------------------------------
\echo '===== a) Preguntas de Laura ====='

-- 1. ¿Qué canciones tiene la playlist 10, en orden, y quiénes son sus artistas?
-- El orden lo da position, no la fecha: 101 y 102 se agregaron el mismo día.
-- Esperado: 3 filas, en orden 101 Ella Baila Sola (Eslabon Armado, Peso Pluma),
-- 102 TQG (Karol G, Shakira), 103 Bzrp Music Sessions #53 (Bizarrap, Shakira).
-- En cada canción, el artista principal va primero.
\echo '--- 1. Canciones de la playlist 10, en orden'
SELECT ps.position,
       s.song_id,
       s.title,
       string_agg(a.artist_name || ' (' || sa.role || ')', ', '
                  ORDER BY sa.role <> 'principal', a.artist_name) AS artistas
FROM playlist_song ps
JOIN songs s        ON s.song_id = ps.song_id
JOIN song_artist sa ON sa.song_id = s.song_id
JOIN artists a      ON a.artist_id = sa.artist_id
WHERE ps.playlist_id = 10
GROUP BY ps.position, s.song_id, s.title
ORDER BY ps.position;

-- 2. ¿Cuántos suscriptores tiene cada suscripción? Que aparezcan también las que no tienen ninguno.
-- Esperado: 4 filas. Familiar 2, Gratuita 1, Premium 1, Estudiante 0.
-- LEFT JOIN conserva Estudiante; COUNT(sb.email) cuenta 0 porque no cuenta los NULL
-- (COUNT(*) contaría 1).
\echo '--- 2. Suscriptores por suscripción'
SELECT su.subscription_type, COUNT(sb.email) AS suscriptores
FROM subscriptions su
LEFT JOIN subscribers sb ON sb.subscription_id = su.subscription_id
GROUP BY su.subscription_id, su.subscription_type
ORDER BY suscriptores DESC, su.subscription_type;

-- 3. ¿Qué canciones no están en ningún álbum?
-- Esperado: 1 fila, 108 Calor de Agosto.
\echo '--- 3. Canciones sin álbum'
SELECT s.song_id, s.title
FROM songs s
LEFT JOIN song_album sal ON sal.song_id = s.song_id
WHERE sal.song_id IS NULL
ORDER BY s.song_id;

-- 4. ¿Qué tiene guardado cada suscriptor en su biblioteca, tanto canciones como álbumes?
-- Esperado: 9 filas. ana: álbum 205 y canciones 102, 104; diego: canciones 101, 108;
-- luis: álbumes 204, 206 y canción 103; marta: una fila con NULL (biblioteca vacía).
\echo '--- 4. Biblioteca de cada suscriptor'
SELECT l.subscriber_email, g.tipo, g.id, g.titulo
FROM libraries l
LEFT JOIN (
    SELECT ls.library_id, 'canción' AS tipo, s.song_id AS id, s.title AS titulo
    FROM library_song ls
    JOIN songs s ON s.song_id = ls.song_id
    UNION ALL
    SELECT la.library_id, 'álbum', al.album_id, al.title
    FROM library_album la
    JOIN albums al ON al.album_id = la.album_id
) g ON g.library_id = l.library_id
ORDER BY l.subscriber_email, g.tipo, g.id;

-- 5. ¿Cuál es la canción más escuchada?
-- No se puede responder: los datos de Laura no registran reproducciones.
-- Haría falta una tabla de reproducciones, por ejemplo
-- plays (subscriber_email, song_id, played_at), y contar sus filas por song_id.
-- Estar en más playlists o bibliotecas no equivale a ser la más escuchada.

-- ---------------------------------------------------------------------
-- b) Intentos de romper las reglas
-- Cada instrucción debe producir un ERROR. psql lo muestra y sigue.
-- ---------------------------------------------------------------------
\echo '===== b) Intentos de romper las reglas (todos deben dar ERROR) ====='

-- PRIMARY KEY: no puede haber dos canciones con el mismo identificador.
-- Esperado: ERROR por llave duplicada (songs_pkey).
INSERT INTO songs (song_id, title, duration_seconds, genre)
VALUES (101, 'Otra canción', 180, 'Pop');

-- PRIMARY KEY compuesta: una canción no se repite dentro de una playlist.
-- Esperado: ERROR por llave duplicada (playlist_song_pkey).
INSERT INTO playlist_song (playlist_id, song_id, position, added_at)
VALUES (10, 101, 4, '2026-07-01');

-- PRIMARY KEY como 1..1: un suscriptor tiene a lo más un perfil.
-- Esperado: ERROR por llave duplicada (profiles_pkey).
INSERT INTO profiles (subscriber_email, display_name, photo)
VALUES ('ana@mail.com', 'ana2', NULL);

-- FOREIGN KEY: toda playlist pertenece a un suscriptor registrado.
-- Esperado: ERROR por violar la llave foránea (playlists_owner_email_fkey).
INSERT INTO playlists (playlist_id, name, created_at, owner_email)
VALUES (99, 'Fantasma', '2026-07-01', 'nadie@mail.com');

-- FOREIGN KEY al borrar: no se puede borrar una canción que está en playlists, álbumes o bibliotecas.
-- Esperado: ERROR por violar la llave foránea.
DELETE FROM songs WHERE song_id = 102;

-- NOT NULL: todo suscriptor tiene exactamente una suscripción (el mínimo de 1 de la relación).
-- Esperado: ERROR por valor nulo en subscription_id.
INSERT INTO subscribers (email, registered_at, subscription_id, country_code)
VALUES ('nulo@mail.com', '2026-07-01', NULL, 'MX');

-- UNIQUE: dos suscripciones no pueden llamarse igual.
-- Esperado: ERROR por llave duplicada (subscriptions_subscription_type_key).
INSERT INTO subscriptions (subscription_id, subscription_type, price, has_ads)
VALUES (99, 'Premium', 150, false);

-- UNIQUE como 1..1: un suscriptor tiene a lo más una biblioteca.
-- Esperado: ERROR por llave duplicada (libraries_subscriber_email_key).
INSERT INTO libraries (library_id, subscriber_email)
VALUES (99, 'ana@mail.com');

-- UNIQUE compuesta: dos canciones no ocupan la misma posición de una playlist.
-- Esperado: ERROR por llave duplicada (playlist_song_playlist_id_position_key).
INSERT INTO playlist_song (playlist_id, song_id, position, added_at)
VALUES (10, 104, 1, '2026-07-01');

-- UNIQUE compuesta: dos canciones no ocupan la misma pista de un álbum.
-- Esperado: ERROR por llave duplicada (song_album_album_id_track_number_key).
INSERT INTO song_album (album_id, song_id, track_number)
VALUES (205, 108, 3);

-- UNIQUE parcial: una canción tiene a lo más un artista principal.
-- Esperado: ERROR por llave duplicada (song_artist_one_principal).
INSERT INTO song_artist (song_id, artist_id, role)
VALUES (101, 'A10', 'principal');

-- CHECK: una suscripción no puede tener precio negativo.
-- Esperado: ERROR por violar la restricción check (subscriptions_price_check).
UPDATE subscriptions SET price = -10 WHERE subscription_id = 2;

-- CHECK: el código de país son exactamente 2 letras mayúsculas.
-- Esperado: ERROR por violar la restricción check (countries_country_code_check).
INSERT INTO countries (country_code, country_name)
VALUES ('mx', 'Mexiquito');

-- CHECK: el rol en una canción solo puede ser 'principal' o 'feat.'.
-- Esperado: ERROR por violar la restricción check (song_artist_role_check).
INSERT INTO song_artist (song_id, artist_id, role)
VALUES (104, 'A11', 'productor');

-- CHECK: una canción dura más de 0 segundos.
-- Esperado: ERROR por violar la restricción check (songs_duration_seconds_check).
UPDATE songs SET duration_seconds = 0 WHERE song_id = 104;

-- ---------------------------------------------------------------------
-- c) Registro y eliminación de un suscriptor (transacciones todo o nada)
--
-- Cómo se comporta psql -f: si una instrucción falla dentro de BEGIN, la transacción
-- queda abortada; las instrucciones siguientes dan "current transaction is aborted"
-- y el COMMIT final se convierte en ROLLBACK. psql sigue con el resto del archivo.
-- ---------------------------------------------------------------------
\echo '===== c) Transacciones ====='

-- c.1 Registro exitoso: suscriptor + perfil + biblioteca.
-- Esperado: antes 0 filas en cada tabla; después 1 en cada una. COMMIT.
\echo '--- c.1 Registro exitoso (antes / después)'
SELECT (SELECT COUNT(*) FROM subscribers WHERE email = 'sofia@mail.com')          AS subscribers,
       (SELECT COUNT(*) FROM profiles    WHERE subscriber_email = 'sofia@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries   WHERE subscriber_email = 'sofia@mail.com') AS libraries;

BEGIN;
INSERT INTO subscribers (email, registered_at, subscription_id, country_code)
VALUES ('sofia@mail.com', '2026-10-01', 2, 'CO');
INSERT INTO profiles (subscriber_email, display_name, photo)
VALUES ('sofia@mail.com', 'sofi', 's5.jpg');
INSERT INTO libraries (library_id, subscriber_email)
VALUES (5, 'sofia@mail.com');
COMMIT;

SELECT (SELECT COUNT(*) FROM subscribers WHERE email = 'sofia@mail.com')          AS subscribers,
       (SELECT COUNT(*) FROM profiles    WHERE subscriber_email = 'sofia@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries   WHERE subscriber_email = 'sofia@mail.com') AS libraries;

-- c.2 Registro que falla a medio camino: el suscriptor y el perfil se insertan, pero la
-- biblioteca usa un library_id que ya existe (1, de ana).
-- Esperado: ERROR por llave duplicada en libraries; el COMMIT responde ROLLBACK.
-- Antes y después: 0 filas en cada tabla. pedro@mail.com no queda sin biblioteca porque no queda.
\echo '--- c.2 Registro fallido (antes / después)'
SELECT (SELECT COUNT(*) FROM subscribers WHERE email = 'pedro@mail.com')          AS subscribers,
       (SELECT COUNT(*) FROM profiles    WHERE subscriber_email = 'pedro@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries   WHERE subscriber_email = 'pedro@mail.com') AS libraries;

BEGIN;
INSERT INTO subscribers (email, registered_at, subscription_id, country_code)
VALUES ('pedro@mail.com', '2026-10-02', 1, 'MX');
INSERT INTO profiles (subscriber_email, display_name, photo)
VALUES ('pedro@mail.com', 'pedrito', NULL);
INSERT INTO libraries (library_id, subscriber_email)
VALUES (1, 'pedro@mail.com');
COMMIT;

SELECT (SELECT COUNT(*) FROM subscribers WHERE email = 'pedro@mail.com')          AS subscribers,
       (SELECT COUNT(*) FROM profiles    WHERE subscriber_email = 'pedro@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries   WHERE subscriber_email = 'pedro@mail.com') AS libraries;

-- Preparación para c.3: sofia@mail.com crea una playlist y guarda canciones y un álbum,
-- para que su eliminación tenga dependientes en todas las tablas.
INSERT INTO playlists (playlist_id, name, created_at, owner_email)
VALUES (15, 'Domingo', '2026-10-03', 'sofia@mail.com');
INSERT INTO playlist_song (playlist_id, song_id, position, added_at) VALUES
    (15, 106, 1, '2026-10-03'),
    (15, 107, 2, '2026-10-03');
INSERT INTO library_song (library_id, song_id) VALUES (5, 106);
INSERT INTO library_album (library_id, album_id) VALUES (5, 205);

-- c.3 Eliminación exitosa de sofia@mail.com. Sin ON DELETE CASCADE: cada borrado es explícito,
-- de las tablas que dependen hacia las que son referenciadas.
-- Esperado antes: 1 suscriptor, 1 perfil, 1 biblioteca, 1 canción y 1 álbum guardados,
-- 1 playlist con 2 canciones. Después: todo en 0.
-- El catálogo no cambia: 8 canciones, 6 álbumes y 11 artistas antes y después.
\echo '--- c.3 Eliminación exitosa (antes / después)'
SELECT (SELECT COUNT(*) FROM subscribers   WHERE email = 'sofia@mail.com')            AS subscribers,
       (SELECT COUNT(*) FROM profiles      WHERE subscriber_email = 'sofia@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries     WHERE subscriber_email = 'sofia@mail.com') AS libraries,
       (SELECT COUNT(*) FROM library_song  WHERE library_id = 5)                      AS library_song,
       (SELECT COUNT(*) FROM library_album WHERE library_id = 5)                      AS library_album,
       (SELECT COUNT(*) FROM playlists     WHERE owner_email = 'sofia@mail.com')      AS playlists,
       (SELECT COUNT(*) FROM playlist_song WHERE playlist_id = 15)                    AS playlist_song,
       (SELECT COUNT(*) FROM songs)   AS songs,
       (SELECT COUNT(*) FROM albums)  AS albums,
       (SELECT COUNT(*) FROM artists) AS artists;

BEGIN;
-- 1. Canciones de sus playlists
DELETE FROM playlist_song
WHERE playlist_id IN (SELECT playlist_id FROM playlists WHERE owner_email = 'sofia@mail.com');
-- 2. Sus playlists
DELETE FROM playlists WHERE owner_email = 'sofia@mail.com';
-- 3. Contenido de su biblioteca
DELETE FROM library_song
WHERE library_id IN (SELECT library_id FROM libraries WHERE subscriber_email = 'sofia@mail.com');
DELETE FROM library_album
WHERE library_id IN (SELECT library_id FROM libraries WHERE subscriber_email = 'sofia@mail.com');
-- 4. Su biblioteca
DELETE FROM libraries WHERE subscriber_email = 'sofia@mail.com';
-- 5. Su perfil
DELETE FROM profiles WHERE subscriber_email = 'sofia@mail.com';
-- 6. El suscriptor
DELETE FROM subscribers WHERE email = 'sofia@mail.com';
COMMIT;

SELECT (SELECT COUNT(*) FROM subscribers   WHERE email = 'sofia@mail.com')            AS subscribers,
       (SELECT COUNT(*) FROM profiles      WHERE subscriber_email = 'sofia@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries     WHERE subscriber_email = 'sofia@mail.com') AS libraries,
       (SELECT COUNT(*) FROM library_song  WHERE library_id = 5)                      AS library_song,
       (SELECT COUNT(*) FROM library_album WHERE library_id = 5)                      AS library_album,
       (SELECT COUNT(*) FROM playlists     WHERE owner_email = 'sofia@mail.com')      AS playlists,
       (SELECT COUNT(*) FROM playlist_song WHERE playlist_id = 15)                    AS playlist_song,
       (SELECT COUNT(*) FROM songs)   AS songs,
       (SELECT COUNT(*) FROM albums)  AS albums,
       (SELECT COUNT(*) FROM artists) AS artists;

-- c.4 Eliminación que falla a medio camino: se borra a luis@mail.com, pero el paso del
-- suscriptor va antes que el del perfil, y profiles todavía apunta a él.
-- Esperado: ERROR por violar la llave foránea profiles_subscriber_email_fkey; el COMMIT
-- responde ROLLBACK. Antes y después: 1 suscriptor, 1 perfil, 1 biblioteca, 1 canción y
-- 2 álbumes guardados, 2 playlists con 5 canciones. Los borrados previos se deshicieron.
\echo '--- c.4 Eliminación fallida (antes / después)'
SELECT (SELECT COUNT(*) FROM subscribers   WHERE email = 'luis@mail.com')            AS subscribers,
       (SELECT COUNT(*) FROM profiles      WHERE subscriber_email = 'luis@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries     WHERE subscriber_email = 'luis@mail.com') AS libraries,
       (SELECT COUNT(*) FROM library_song  WHERE library_id = 2)                     AS library_song,
       (SELECT COUNT(*) FROM library_album WHERE library_id = 2)                     AS library_album,
       (SELECT COUNT(*) FROM playlists     WHERE owner_email = 'luis@mail.com')      AS playlists,
       (SELECT COUNT(*) FROM playlist_song WHERE playlist_id IN (12, 14))            AS playlist_song;

BEGIN;
DELETE FROM playlist_song
WHERE playlist_id IN (SELECT playlist_id FROM playlists WHERE owner_email = 'luis@mail.com');
DELETE FROM playlists WHERE owner_email = 'luis@mail.com';
DELETE FROM library_song
WHERE library_id IN (SELECT library_id FROM libraries WHERE subscriber_email = 'luis@mail.com');
DELETE FROM library_album
WHERE library_id IN (SELECT library_id FROM libraries WHERE subscriber_email = 'luis@mail.com');
DELETE FROM libraries WHERE subscriber_email = 'luis@mail.com';
-- Orden incorrecto: el suscriptor antes que su perfil.
DELETE FROM subscribers WHERE email = 'luis@mail.com';
DELETE FROM profiles WHERE subscriber_email = 'luis@mail.com';
COMMIT;

SELECT (SELECT COUNT(*) FROM subscribers   WHERE email = 'luis@mail.com')            AS subscribers,
       (SELECT COUNT(*) FROM profiles      WHERE subscriber_email = 'luis@mail.com') AS profiles,
       (SELECT COUNT(*) FROM libraries     WHERE subscriber_email = 'luis@mail.com') AS libraries,
       (SELECT COUNT(*) FROM library_song  WHERE library_id = 2)                     AS library_song,
       (SELECT COUNT(*) FROM library_album WHERE library_id = 2)                     AS library_album,
       (SELECT COUNT(*) FROM playlists     WHERE owner_email = 'luis@mail.com')      AS playlists,
       (SELECT COUNT(*) FROM playlist_song WHERE playlist_id IN (12, 14))            AS playlist_song;
