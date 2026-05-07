# Pretendard Variable

Place the following font files here, then rebuild:

- `Pretendard-Regular.ttf`
- `Pretendard-Medium.ttf`
- `Pretendard-SemiBold.ttf`

Source: https://github.com/orioncactus/pretendard/releases (latest static fonts)
License: SIL Open Font License 1.1 (commercial use OK; attribution required in app's Acknowledgments).

Until the .ttf files are present, `Font.custom("Pretendard-…", fixedSize:)` calls fall back to the system font automatically — UI does not break.

`FontRegistration.registerOnce()` (in `Components/FontRegistration.swift`) is invoked from `GyeolApp.init()` and registers any .ttf found in `Bundle.module/Fonts`. No additional code change required when fonts are added.
