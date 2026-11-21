-- English E1_2A classroom introductions. Cues were authored from captured game
-- frames, not the animation start keys (the paper animation starts ~9s early).
-- Voice bounds: shipped CU_E1_2A cue/AkEvent metadata, with conservative margins.
-- The continuation and Jefferson's lesson run concurrently; lesson is NOT a
-- substitute clock. The return visit uses its own Matinee.
return {
    level='E1_2A',
    order={'intro','ending','returning'},
    stages={
        intro={actor='E1_2A_ArtClass_LD_MaxAwake_01',length=20.604443,
            -- Whoa! .410+.520; surreal2.011+1.902;
            -- reassurance10.153+5.195 (English WEM container ~5.253).
            protect={{0,4.45},{9.60,15.90}},
            cues={{start=4.50,finish=6.00,key='scene_classroom_room'},
                  {start=15.95,finish=17.00,key='scene_classroom_pen'},
                  {start=18.50,finish=19.60,key='scene_classroom_paper'}},
        },
        -- Return visit. Eight English Max voice keys from the DNE track, with
        -- DurationINT from the shipped voice assets. Allow a margin on both
        -- sides. The 11.202 line lasts 4.885 seconds, the next starts at 19.652.
        returning={actor='E1_2A_ArtClass_LD_MaxAwake_02',length=33.761524,
            protect={{0,16.55},{19.10,33.80}},
            cues={{start=16.60,finish=17.30,key='scene_classroom_return'}},
        },
        ending={actor='E1_2A_ArtClass_LD_MaxAwake_01End',length=12.040783,
            -- MaxAwake01_Max_020 at5.236549, duration5.923. Protect through
            -- the end: don't start a belated repeat in the tiny final gap.
            protect={{4.70,12.10}},cues={},
        },
    },
}
