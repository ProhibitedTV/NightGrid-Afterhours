# NightGrid Afterhours title screen — neon-grunge editorial direction

The title should feel like an original alternative record sleeve: dark ink, muted magenta and cyan, industrial silhouettes, warm horizon, sparse rain, and bold studio/game typography. The graphic city artwork is deliberately illustrative, not actual gameplay or a canonical map. It does not load or change 3D city geometry, lights, shaders or saves.

The main menu aligns left on wide windows and centers on smaller ones. Existing button IDs, controller focus order, actions, save availability, and destructive New Game confirmation remain intact. The title uses the fixed-city New Game wording from #561. The animated title background preference is persisted alongside interface settings; off means static artwork. Animation redraw is capped at 20 Hz, stops on gameplay entry, and is removed when opening another menu. No new textures, fonts, sound files or model dependencies.

Native review: check 1920x1080, 1280x720, narrow window, keyboard/mouse and gamepad, disabled Continue, New Game confirmation/cancel, settings motion toggle, and pause/resume. Capture real title UI and measure menu frame pacing on RTX 3060 before visual approval. The original title score is a future approved music asset; this change intentionally does not play unreviewed candidates or alter radio behavior.
