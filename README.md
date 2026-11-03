# BD transaccional de Spotify

Implementación en PostgreSQL 18 de la base de datos transaccional de Spotify (Tarea 3), a partir del diagrama ER de la Tarea 2. Se carga con los datos de Laura (tablas A, B, C y D) y se comprueba que sus reglas de negocio se cumplen.

Este repositorio es el punto de partida de las siguientes prácticas del curso.

## Contexto

Laura nos envió cuatro exports de su sistema anterior: playlists (A), créditos de canciones (B), álbumes (C) y suscriptores con su biblioteca (D). En la Tarea 2 los normalizamos hasta 3FN y construimos el diagrama ER. En esta tarea:

- `db/01_schema.sql` crea las tablas con sus tipos de dato, llaves y restricciones.
- `db/02_seed.sql` inserta los datos de Laura con sus identificadores originales (`song_id`, `album_id`, `artist_id`, `playlist_id`), más los casos extra que pide el enunciado.
- `tests.sql` responde las preguntas de Laura, intenta romper cada tipo de restricción y prueba las transacciones de registro y eliminación de un suscriptor.

## Estructura

```
├── db/
│   ├── 01_schema.sql      # CREATE TABLE (se ejecuta al inicializar)
│   └── 02_seed.sql        # INSERT de los datos iniciales (se ejecuta al inicializar)
├── docs/
│   ├── diagrama_conceptual.png
│   └── diagrama_er.png
├── .env.example           # plantilla de credenciales (el .env real no se sube)
├── .gitignore
├── docker-compose.yml
├── tests.sql
└── README.md
```

## Modelo

| Tabla | Llave primaria | Relaciones |
|---|---|---|
| `countries` | `country_code` | |
| `subscriptions` | `subscription_id` | |
| `songs` | `song_id` | |
| `subscribers` | `email` | → subscriptions, countries |
| `artists` | `artist_id` | → countries |
| `profiles` | `subscriber_email` | → subscribers (1:1) |
| `libraries` | `library_id` | → subscribers (1:1, `subscriber_email` UNIQUE) |
| `playlists` | `playlist_id` | → subscribers (dueño) |
| `albums` | `album_id` | → artists |
| `song_artist` | (`song_id`, `artist_id`) | songs ↔ artists, con `role` |
| `song_album` | (`album_id`, `song_id`) | albums ↔ songs, con `track_number` |
| `playlist_song` | (`playlist_id`, `song_id`) | playlists ↔ songs, con `position` y `added_at` |
| `library_song` | (`library_id`, `song_id`) | libraries ↔ songs |
| `library_album` | (`library_id`, `album_id`) | libraries ↔ albums |

Ninguna llave foránea usa `ON DELETE CASCADE`: los borrados son explícitos (ver la transacción de eliminación en `tests.sql`).

## Cambios respecto al diagrama ER de la Tarea 2

| Cambio | Motivo |
|---|---|
| Nombres de tablas y columnas en inglés (`subscribers`, `songs`, `playlist_song`...) | Convención de nombres de la Tarea 2: entidades en plural, tablas de unión con el singular de ambas entidades, atributos en snake_case |
| Nuevas entidades `profiles` y `libraries`, separadas de `subscribers` | Están en el diagrama conceptual unificado, y el enunciado pide registrar y eliminar al suscriptor junto con su perfil y su biblioteca. `nombre_visible` y `foto` pasan a `profiles` |
| `library_song` y `library_album` (antes `SUSCRIPTOR_CANCION` y `SUSCRIPTOR_ALBUM`) apuntan a `libraries` en vez de al email | Lo guardado pertenece a la biblioteca |
| `ALBUM_PISTA` pasa a ser `song_album` | Convención de nombres de las tablas de unión |
| `subscriptions` usa una llave sustituta `subscription_id`; el nombre del tipo queda `UNIQUE` | El nombre puede cambiar y no usamos `ON UPDATE CASCADE` |
| Nueva columna `playlist_song.position` | La pregunta 1 pide las canciones en orden, y la fecha no basta: en la playlist 10, la 101 y la 102 se agregaron el mismo día |
| `duracion time` pasa a `duration_seconds integer` | `time` es una hora del día: interpretaría `2:45` como 2 horas 45 minutos |
| `anuncios string` pasa a `has_ads boolean` | Solo admite sí o no |

## Supuestos

- **IDs inventados:** los `subscription_id` (1–4) y los `library_id` (1–4) los asignamos nosotros, porque Laura no los trae.
- **Email del suscriptor:** identifica al suscriptor y no cambia.
- **Canciones en una playlist:** una canción no se repite dentro de la misma playlist (PK `(playlist_id, song_id)`).
- **Posición en la playlist:** es el orden en que aparecen las canciones en la celda de la tabla A.
- **Artista principal:** toda canción tiene exactamente un artista `principal` y cero o más `feat.`. Un índice `UNIQUE` parcial impide que haya dos principales.
- **Álbumes:** una canción puede estar en varios álbumes (TQG está en 202 y 206) o en ninguno (108). El artista de un álbum no tiene que ser el artista principal de todas sus canciones.
- **Mínimos que no se pueden forzar con una llave foránea:** se documentan como supuestos.
  - Toda canción tiene al menos un artista.
  - Todo álbum tiene al menos una canción.
  - Todo suscriptor tiene perfil y biblioteca. Este último lo garantiza la transacción de registro, que crea los tres registros o ninguno.
- **Foto opcional:** la foto del perfil puede faltar (marta@mail.com).
- **Biblioteca vacía:** una biblioteca puede estar vacía (marta@mail.com).
- **Nombres de playlist:** el nombre de una playlist no es único ("Gym" existe para ana y para luis).
- **Casos extra del seed:**
  - Agregados por nosotros: la suscripción `Estudiante`, sin suscriptores, y el artista `A11`, sin canciones ni álbumes.
  - Ya presentes en los datos de Laura: la playlist vacía (13) y la canción sin álbum (108).
- **Canción más escuchada (pregunta 5):** no se puede responder porque los datos no registran reproducciones. Haría falta una tabla como `plays (subscriber_email, song_id, played_at)`.

## Cómo iniciar PostgreSQL

Requisitos: Docker y Docker Compose. En Windows, el enunciado los instala dentro de WSL 2 + Ubuntu.

1. Clona el repositorio y entra a la carpeta:

   ```bash
   git clone <url-del-repositorio>
   cd <carpeta-del-repositorio>
   ```

2. Crea tu `.env` a partir de la plantilla y completa sus valores. El `.env` nunca se sube al repositorio.

   ```bash
   cp .env.example .env
   ```

3. Inicia PostgreSQL. Si el volumen está vacío, la imagen crea el usuario y la base de datos, y ejecuta en orden los archivos de `db/`:

   ```bash
   docker compose up -d
   ```

   El comando termina antes que la inicialización; espera unos segundos.

4. Revisa que la inicialización no haya tenido errores. Si no aparece nada, no hubo errores:

   ```bash
   docker compose logs postgres | grep ERROR
   ```

   Si aparece algo, corrige el archivo y repite desde `docker compose down -v`, porque `db/` solo se ejecuta con un volumen vacío.

## Cómo ejecutar las pruebas

```bash
docker compose exec postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB> -f /tests.sql
```

Usa los valores de usuario y base de datos de tu `.env`. Compara la salida con los comentarios de `tests.sql`:

- **a) Preguntas de Laura:** cada consulta indica el resultado esperado.
- **b) Intentos de romper las reglas:** cada uno debe mostrar un `ERROR` con la restricción indicada. psql lo muestra y sigue con la siguiente instrucción.
- **c) Transacciones:** en los casos fallidos, el `COMMIT` responde `ROLLBACK`, y las consultas de antes y después muestran los mismos conteos.

`tests.sql` se puede ejecutar varias veces con el mismo resultado. Si una ejecución se interrumpe a la mitad, reinicia con `docker compose down -v` y `docker compose up -d`.

## Comandos útiles

| Qué quieres hacer | Comando |
|---|---|
| Ver si el contenedor está corriendo | `docker compose ps` |
| Abrir una consola SQL (se sale con `\q`) | `docker compose exec postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB>` |
| Detener PostgreSQL y conservar los datos | `docker compose down` |
| Eliminar también todos los datos | `docker compose down -v` |
