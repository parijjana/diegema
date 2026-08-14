/// Shared HTTP User-Agent for all outbound requests to librivox.org and
/// archive.org. Archive.org etiquette expects a descriptive UA with a way to
/// reach whoever is running the client; keep this in sync across every
/// service that talks to it.
///
/// The contact is a **project** address, never a personal one. This string is
/// sent on every outbound request and lives in a public repo, so a personal
/// address here is a spam magnet — the previous value carried the owner's
/// own Gmail. Update the URL and the name, not the etiquette, if the project
/// moves or is renamed after the community picks a name.
const String kHttpUserAgent =
    'Diegema/1.0 (+https://github.com/parijjana/diegema; '
    'overengineeredhobbies@gmail.com)';
