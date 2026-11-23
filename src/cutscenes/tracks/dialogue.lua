-- Authored dialogue protection for BUNDLED movie tracks, in playback seconds.
-- Keys match language/episode/movie identity, without the .ad.srt suffix.
-- Preserve these bounds when moving SRT cues; user overrides own their timing.
-- See descriptions/movies.md before adding a movie or another language.
return {
    ['en/episode01/bik_e1_7a_snowing.mp4']={{0,74.55},{80.5,97.2}},
    ['en/episode01/bik_e1_6a_dialend.mp4']={{17.75,23.3},{28.9,36.45}},
}
