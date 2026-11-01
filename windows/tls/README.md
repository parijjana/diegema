`cacert.pem` is Mozilla's root certificate list as published by curl
(https://curl.se/docs/caextract.html; MPL 2.0). libmpv needs it to verify HTTPS.
Checksum verified against https://curl.se/ca/cacert.pem.sha256 when fetched.
Replace it with the latest copy before each Windows release.
