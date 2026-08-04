/// Shared HTTP User-Agent for all outbound requests to librivox.org and
/// archive.org. Archive.org etiquette expects a descriptive UA with a
/// contact email; keep this in sync across every service that talks to it.
const String kHttpUserAgent =
    'AulosAudiobookPlayer/1.0 (Mozilla/5.0; overengineeredhobbies@gmail.com)';
