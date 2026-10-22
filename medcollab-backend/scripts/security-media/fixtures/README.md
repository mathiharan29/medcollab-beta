# Synthetic MP4 fixture

`canary.mp4` is an authored black 16×16 single-frame H.264 MP4 (1,509 bytes). It contains no external input, audio, identifying data or clinical content. SHA-256: `d52c25883ebab2b9d7a9f416f4a7e7d118ff429eb68e85bbf295f34d99c70ae7`.

The bytes were authored on the disposable Ubuntu runner during run 37180593760, using an FFmpeg `lavfi` black color source, and recovered from its sanitized artifact. They are now versioned and hash-pinned; ordinary test execution requires no FFmpeg installation or media download.

This valid-container fixture establishes the exact bytes Vocle forwards. The SDK double never decodes them. Cloudinary acceptance, transcoding and playable delivery remain Stage 3 questions. PNG bytes and the inert one-page PDF with calculated xref offsets are authored in `helpers.js`.
