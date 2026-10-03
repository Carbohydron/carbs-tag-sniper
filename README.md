# Carbs Tag Sniper

A World of Warcraft: Forever addon that helps you snipe the tag on a named quest mob.

Carbs Tag Sniper creates and maintains a character macro named `CTSnipe` that targets a named
mob and hits it with an instant ability from your class, so when the mob respawns you can tag
it before anyone else. Put the macro on a key or your mouse wheel and spam it.

## Installation

Install it from CurseForge or Wago Addons with your addon manager, or download the zip from
the GitHub release and extract it into `Interface/AddOns/`.

For development, copy (or symlink) this folder into your WoW `Interface/AddOns/` directory so the path is
`Interface/AddOns/Carbs-Tag-Sniper/Carbs-Tag-Sniper.toc`, then restart the game or `/reload`.

## Usage

1. Set the mob: `/cts target Rotting Dead`, or target it and type `/cts target`.
2. Open `/macro`, Character Specific tab, and drag `CTSnipe` to an action bar.
3. Bind it however you like (the addon never binds keys for you; mouse wheel works well).
4. Spam it while you wait for the respawn.

```
/cts                    help and current settings
/cts target <mob name>  mob to snipe (no name = your current target)
/cts spell <spell>      tag spell for this character (saved per character)
/cts spell attack       tag with melee (/startattack) instead of a spell
/cts spell reset        go back to the class default
/cts mark <1-8|off>     raid marker for the mob (default 7, cross)
/cts quiet <on|off>     mute error speech and error text while spamming (default on)
/cts update             rebuild the macro now
/cts show               print the macro text
```

## The macro

```
#showtooltip
/cleartarget
/targetexact Rotting Dead
/stopmacro [noexists][dead]
/tm 7
/console Sound_EnableErrorSpeech 0
/cast Fire Blast
/startattack
/run CTSPost()
```

- The target is cleared first, so if the mob isn't up (or is dead) the macro stops and does
  nothing, instead of firing at whatever you had targeted before.
- Error speech is muted with `/console` before the cast; `CTSPost` restores your setting and
  clears the red error text.
- On Forever, `/run` code is always tainted ("ForceTaint_Strong"), so `/run` must never call a
  protected function such as `SetRaidTarget`. The raid mark uses the secure `/tm` command.
- The macro is only rewritten when its text actually changes, and never in combat (changes
  wait for combat to end).

Default tag spells are instant and deal damage. The first one your character knows is used:
Paladin Holy Shock or Judgement, Hunter Arcane Shot or Serpent Sting, Priest Shadow Word: Pain,
Shaman Earth/Flame/Frost Shock, Mage Fire Blast, Warlock Bane of Agony, Druid Moonfire or
Insect Swarm. Warriors, Rogues, and anyone who hasn't learned one yet tag with melee through
`/startattack`. Override with `/cts spell`.

Errors the server reports after the cast (such as line of sight) arrive after speech is
restored, so those can still make a sound.

## Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) in
`.github/workflows/release.yml`. Pushing a tag starting with `v` builds
`Carbs-Tag-Sniper-<tag>-forever.zip`, stamps the tag into the `.toc` version, and uploads it to
CurseForge, Wago Addons and a GitHub release. A tag containing `alpha` or `beta` is uploaded
as an alpha or beta.

1. Add the new version's notes to `CHANGELOG.md` and commit.
2. `git tag -a v1.2.3 -m "v1.2.3"` then `git push origin v1.2.3`.

Uploads need the `CF_API_KEY` and `WAGO_API_TOKEN` repository secrets and the
`X-Curse-Project-ID` and `X-Wago-ID` lines in the `.toc`. A site without them is skipped.

## License

MIT, see [LICENSE](LICENSE).
