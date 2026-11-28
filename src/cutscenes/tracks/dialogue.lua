-- Authored dialogue protection for BUNDLED movie tracks, in playback seconds.
-- Keys match language/episode/movie identity, without the .ad.srt suffix.
-- Preserve these bounds when moving SRT cues; user overrides own their timing.
-- See descriptions/movies.md before adding a movie or another language.
return {
    ['en/episode01/bik_e1_7a_snowing.mp4']={{0,74.55},{80.5,97.2}},
    ['en/episode01/bik_e1_6a_dialend.mp4']={{17.75,23.3},{28.9,36.45}},
    -- The visions use storm sounds. The eclipse montages play to music.
    ['en/episode02/bik_e2_3a_vision.mp4']={},
    ['en/episode02/bik_e2_3b_vision.mp4']={},
    ['en/episode02/bik_e2_7a_eclipse1.mp4']={},
    ['en/episode02/bik_e2_7a_eclipse2a.mp4']={},
    ['en/episode02/bik_e2_7a_eclipse2b.mp4']={},
    ['en/episode02/bik_e2_7a_eclipse3.mp4']={},
    ['en/episode02/bik_e2_7a_eclipsekatealive.mp4']={},
    ['en/episode02/bik_e2_7a_eclipsekatedead.mp4']={},
    -- The English recap cuts between lines from Episode 1. Leave only the
    -- measured gaps open, including on a reread.
    ['en/episode02/bik_previously_e2.mp4']={{0,4.76},{6.4,9.64},{11.24,66.23}},
    ['en/episode02/bik_teaser_e2.mp4']={},
}
