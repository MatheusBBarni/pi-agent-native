# Theme Color Variants

This document collects dark and light color variants for Nord, Dracula, Catppuccin, One Dark, and Night Owl.

Source policy:

- Prefer official theme sites or upstream repositories.
- When a theme exposes HSL variables instead of hex values, the hex values below are converted from the upstream HSL values.
- Nord does not publish separate official "Nord Dark" and "Nord Light" palettes. The dark/light mappings below are derived from Nord's official usage guidance: Polar Night colors as dark backgrounds and Snow Storm colors as light backgrounds.

## Sources

- Nord: https://www.nordtheme.com/ and https://github.com/nordtheme/nord/blob/develop/src/nord.scss
- Dracula: https://draculatheme.com/spec
- Catppuccin: https://catppuccin.com/palette/ and https://github.com/catppuccin/palette/blob/main/palette.json
- One Dark: https://github.com/atom/one-dark-syntax/blob/master/styles/colors.less
- One Light: https://github.com/atom/one-light-syntax/blob/master/styles/colors.less
- Night Owl: https://github.com/sdras/night-owl-vscode-theme
- Night Owl dark theme file: https://github.com/sdras/night-owl-vscode-theme/blob/main/themes/Night%20Owl-color-theme.json
- Night Owl light theme file: https://github.com/sdras/night-owl-vscode-theme/blob/main/themes/Night%20Owl-Light-color-theme.json

## Nord

Official Nord is one 16-color palette organized into Polar Night, Snow Storm, Frost, and Aurora.

### Full Official Palette

| Token | Group | Hex |
| --- | --- | --- |
| nord0 | Polar Night | `#2e3440` |
| nord1 | Polar Night | `#3b4252` |
| nord2 | Polar Night | `#434c5e` |
| nord3 | Polar Night | `#4c566a` |
| nord4 | Snow Storm | `#d8dee9` |
| nord5 | Snow Storm | `#e5e9f0` |
| nord6 | Snow Storm | `#eceff4` |
| nord7 | Frost | `#8fbcbb` |
| nord8 | Frost | `#88c0d0` |
| nord9 | Frost | `#81a1c1` |
| nord10 | Frost | `#5e81ac` |
| nord11 | Aurora | `#bf616a` |
| nord12 | Aurora | `#d08770` |
| nord13 | Aurora | `#ebcb8b` |
| nord14 | Aurora | `#a3be8c` |
| nord15 | Aurora | `#b48ead` |

### Nord Dark Mapping

| Role | Color |
| --- | --- |
| App/background | `#2e3440` |
| Sidebar/elevated surface | `#3b4252` |
| Selection/line highlight | `#434c5e` |
| Muted/comment text | `#4c566a` |
| Primary text | `#d8dee9` |
| Strong text | `#eceff4` |
| Primary accent | `#88c0d0` |
| Secondary accent | `#81a1c1` |
| Error | `#bf616a` |
| Warning | `#ebcb8b` |
| Success | `#a3be8c` |
| Special/purple | `#b48ead` |

### Nord Light Mapping

| Role | Color |
| --- | --- |
| App/background | `#eceff4` |
| Sidebar/elevated surface | `#e5e9f0` |
| Panel surface | `#d8dee9` |
| Selection/line highlight | `#d8dee9` |
| Primary text | `#2e3440` |
| Secondary text | `#4c566a` |
| Primary accent | `#5e81ac` |
| Secondary accent | `#88c0d0` |
| Error | `#bf616a` |
| Warning | `#d08770` |
| Success | `#a3be8c` |
| Special/purple | `#b48ead` |

## Dracula

Dracula's current official spec defines a dark variant, Dracula Classic, and a light variant, Alucard Classic.

### Dracula Classic

| Token | Hex |
| --- | --- |
| Background | `#282A36` |
| Current Line | `#6272A4` |
| Selection | `#44475A` |
| Foreground | `#F8F8F2` |
| Comment | `#6272A4` |
| Red | `#FF5555` |
| Orange | `#FFB86C` |
| Yellow | `#F1FA8C` |
| Green | `#50FA7B` |
| Cyan | `#8BE9FD` |
| Purple | `#BD93F9` |
| Pink | `#FF79C6` |
| Background lighter | `#424450` |
| Background light | `#343746` |
| Background dark | `#21222C` |
| Background darker | `#191A21` |

### Alucard Classic

| Token | Hex |
| --- | --- |
| Background | `#FFFBEB` |
| Current Line | `#6C664B` |
| Selection | `#CFCFDE` |
| Foreground | `#1F1F1F` |
| Comment | `#6C664B` |
| Red | `#CB3A2A` |
| Orange | `#A34D14` |
| Yellow | `#846E15` |
| Green | `#14710A` |
| Cyan | `#036A96` |
| Purple | `#644AC9` |
| Pink | `#A3144D` |
| Background lighter | `#ECE9DF` |
| Background light | `#DEDCCF` |
| Background dark | `#CECCC0` |
| Background darker | `#BCBAB3` |

## Catppuccin

Catppuccin has one official light flavor, Latte, and three official dark flavors: Frappe, Macchiato, and Mocha.

### Latte

| Token | Hex |
| --- | --- |
| Rosewater | `#dc8a78` |
| Flamingo | `#dd7878` |
| Pink | `#ea76cb` |
| Mauve | `#8839ef` |
| Red | `#d20f39` |
| Maroon | `#e64553` |
| Peach | `#fe640b` |
| Yellow | `#df8e1d` |
| Green | `#40a02b` |
| Teal | `#179299` |
| Sky | `#04a5e5` |
| Sapphire | `#209fb5` |
| Blue | `#1e66f5` |
| Lavender | `#7287fd` |
| Text | `#4c4f69` |
| Subtext 1 | `#5c5f77` |
| Subtext 0 | `#6c6f85` |
| Overlay 2 | `#7c7f93` |
| Overlay 1 | `#8c8fa1` |
| Overlay 0 | `#9ca0b0` |
| Surface 2 | `#acb0be` |
| Surface 1 | `#bcc0cc` |
| Surface 0 | `#ccd0da` |
| Base | `#eff1f5` |
| Mantle | `#e6e9ef` |
| Crust | `#dce0e8` |

### Frappe

| Token | Hex |
| --- | --- |
| Rosewater | `#f2d5cf` |
| Flamingo | `#eebebe` |
| Pink | `#f4b8e4` |
| Mauve | `#ca9ee6` |
| Red | `#e78284` |
| Maroon | `#ea999c` |
| Peach | `#ef9f76` |
| Yellow | `#e5c890` |
| Green | `#a6d189` |
| Teal | `#81c8be` |
| Sky | `#99d1db` |
| Sapphire | `#85c1dc` |
| Blue | `#8caaee` |
| Lavender | `#babbf1` |
| Text | `#c6d0f5` |
| Subtext 1 | `#b5bfe2` |
| Subtext 0 | `#a5adce` |
| Overlay 2 | `#949cbb` |
| Overlay 1 | `#838ba7` |
| Overlay 0 | `#737994` |
| Surface 2 | `#626880` |
| Surface 1 | `#51576d` |
| Surface 0 | `#414559` |
| Base | `#303446` |
| Mantle | `#292c3c` |
| Crust | `#232634` |

### Macchiato

| Token | Hex |
| --- | --- |
| Rosewater | `#f4dbd6` |
| Flamingo | `#f0c6c6` |
| Pink | `#f5bde6` |
| Mauve | `#c6a0f6` |
| Red | `#ed8796` |
| Maroon | `#ee99a0` |
| Peach | `#f5a97f` |
| Yellow | `#eed49f` |
| Green | `#a6da95` |
| Teal | `#8bd5ca` |
| Sky | `#91d7e3` |
| Sapphire | `#7dc4e4` |
| Blue | `#8aadf4` |
| Lavender | `#b7bdf8` |
| Text | `#cad3f5` |
| Subtext 1 | `#b8c0e0` |
| Subtext 0 | `#a5adcb` |
| Overlay 2 | `#939ab7` |
| Overlay 1 | `#8087a2` |
| Overlay 0 | `#6e738d` |
| Surface 2 | `#5b6078` |
| Surface 1 | `#494d64` |
| Surface 0 | `#363a4f` |
| Base | `#24273a` |
| Mantle | `#1e2030` |
| Crust | `#181926` |

### Mocha

| Token | Hex |
| --- | --- |
| Rosewater | `#f5e0dc` |
| Flamingo | `#f2cdcd` |
| Pink | `#f5c2e7` |
| Mauve | `#cba6f7` |
| Red | `#f38ba8` |
| Maroon | `#eba0ac` |
| Peach | `#fab387` |
| Yellow | `#f9e2af` |
| Green | `#a6e3a1` |
| Teal | `#94e2d5` |
| Sky | `#89dceb` |
| Sapphire | `#74c7ec` |
| Blue | `#89b4fa` |
| Lavender | `#b4befe` |
| Text | `#cdd6f4` |
| Subtext 1 | `#bac2de` |
| Subtext 0 | `#a6adc8` |
| Overlay 2 | `#9399b2` |
| Overlay 1 | `#7f849c` |
| Overlay 0 | `#6c7086` |
| Surface 2 | `#585b70` |
| Surface 1 | `#45475a` |
| Surface 0 | `#313244` |
| Base | `#1e1e2e` |
| Mantle | `#181825` |
| Crust | `#11111b` |

## One Dark / One Light

The upstream Atom themes define colors in LESS as HSL variables. The values below are converted to hex.

### One Dark

| Token | Hex |
| --- | --- |
| Background | `#282c34` |
| Default text | `#abb2bf` |
| Secondary text | `#828997` |
| Comment/muted | `#5c6370` |
| Cyan | `#56b6c2` |
| Blue | `#61afef` |
| Purple | `#c678dd` |
| Green | `#98c379` |
| Red | `#e06c75` |
| Red alternate | `#be5046` |
| Orange | `#d19a66` |
| Yellow | `#e5c07b` |
| Accent | `#528bff` |

### One Light

| Token | Hex |
| --- | --- |
| Background | `#fafafa` |
| Default text | `#383a42` |
| Secondary text | `#696c77` |
| Comment/muted | `#a0a1a7` |
| Cyan | `#0184bc` |
| Blue | `#4078f2` |
| Purple | `#a626a4` |
| Green | `#50a14f` |
| Red | `#e45649` |
| Red alternate | `#ca1243` |
| Orange | `#986801` |
| Yellow/orange alternate | `#c18401` |
| Accent | `#526eff` |

## Night Owl

Night Owl is primarily a VS Code theme, so its source colors are defined as editor UI colors and token foreground values.

### Night Owl

| Role | Hex |
| --- | --- |
| Editor/app background | `#011627` |
| Foreground | `#d6deeb` |
| Selection | `#1d3b53` |
| Line highlight | `#28707d29` |
| Cursor | `#80a4c2` |
| Focus/contrast border | `#122d42` |
| Sidebar background | `#011627` |
| Active tab background | `#0b2942` |
| Input background | `#0b253a` |
| Button background | `#7e57c2cc` |
| Error foreground | `#EF5350` |

Representative syntax colors:

| Role | Hex |
| --- | --- |
| Blue | `#82AAFF` |
| Light blue | `#5ca7e4` |
| Cyan | `#7fdbca` |
| Bright cyan | `#31e1eb` |
| Purple | `#C792EA` |
| Orange | `#F78C6C` |
| Yellow | `#ecc48d` |
| Light yellow | `#FFCB8B` |
| Green | `#c5e478` |
| Red | `#ff5874` |
| Muted text | `#5f7e97` |

### Night Owl Light

| Role | Hex |
| --- | --- |
| Editor/app background | `#FBFBFB` |
| Foreground | `#403f53` |
| Selection | `#E0E0E0` |
| Line highlight | `#F0F0F0` |
| Cursor | `#90A7B2` |
| Sidebar background | `#F0F0F0` |
| Active tab background | `#F6F6F6` |
| Input background | `#F0F0F0` |
| Button background | `#2AA298` |
| Terminal background | `#F6F6F6` |
| Terminal foreground | `#403f53` |

Representative syntax colors:

| Role | Hex |
| --- | --- |
| Purple | `#994CC3` |
| Blue | `#4876d6` |
| Cyan/teal | `#0c969b` |
| Green | `#8BD649` |
| Red | `#bc5454` |
| Dark red | `#d3423e` |
| Pink | `#ff2c83` |
| Dark pink | `#aa0982` |
| Muted blue-gray | `#989fb1` |
| Secondary muted | `#939dbb` |
