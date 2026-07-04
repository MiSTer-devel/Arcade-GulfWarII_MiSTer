# Comad's Gulf War II

## Disclosures

**THIS IS A VIBE CODED CORE BASED ON MAME AND ERIN OLAFSON'S
[EXCELLENT TOAPLAN MiSTer FRAMEWORK](https://github.com/va7deo/). IT HAS BEEN EXTENSIVELY TESTED AND MATCHED TO MAME BEHAVIOR (TO THE BEST OF MY ABILITY)**

## Overview

I think, rather than try to summarize the game for you, it's better to just pull the overview from the [Bootleg Games Wiki](https://bootleggames.fandom.com/wiki/Gulf_War_II)

>The game takes place in the real Gulf War, which happened from 1990-1991. The players fights against Iraq armed forces in 10 stages full of action, but starting from stage 11, the game loops back from stage 1, but on harder difficulties.

Now, before you ask...

>As the title suggests it was a "sequel" to the first Gulf War game, there was never a Gulf War I...

## Notes

- Some CRTs might struggle with the weird 54.9hz refresh rate that the core spits out (both my Sony L5s hate it - but the JVCs are fine with it). There is an toggle in the Video Options to force 60hz.

## Project Basis

- Toaplan scaffolding: based on Erin Olafson / va7deo's
  [`Toaplan Work`](https://github.com/va7deo?tab=repositories) and the wider va7deo Toaplan core family.
- Behavioral reference: MAME's Toaplan driver behavior for Gulf War II,
  `toaplan_dsp.cpp`, and shared Toaplan video devices.
- ROM definitions and MRAs: based on MAME 0.287 set definitions.
- Code written by Codex

## External Modules

| Local path | Function | Credit / upstream |
| --- | --- | --- |
| `rtl/modules/fx68k/` | Motorola 68000 compatible CPU | Jorge Cwik / [jtPerceval/fx68k](https://github.com/jtPerceval/fx68k) |
| `rtl/modules/T80/` | Z80 compatible sound CPU | Daniel Wallner, MikeJ, Sorgelig, and [T80 contributors](https://github.com/mist-devel/T80) |
| `rtl/modules/opl2_fpga_MiSTer/` | Active YM3812/OPL2 audio path | [gtaylormb/opl2_fpga_MiSTer](https://github.com/gtaylormb/opl2_fpga_MiSTer), derived from `opl3_fpga`/`opl2_fpga` work |
| `rtl/modules/IKA32010/` | TMS320C10-class DSP softcore | Sehyeon Kim (Raki) / [ika-musume/IKA32010](https://github.com/ika-musume/IKA32010) |
