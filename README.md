# Redmine Project Colors Plugin

This plugin shows each project name in the project color. Each project gets its color in a project custom field with the format "Color". This project is not intended for public use, it was created
for our internal company needs. But you can use it if you want.

The plugin does not require a database migration. It adds the custom field format "Color" and one plugin setting.

This plugin is a fork of [Redmine Progressive Projects List Plugin](https://github.com/ergoserv/redmine-progressive-projects-list), although almost nothing left from the original code.

## Compatibility
The plugin is tested with Redmine 7.0.3. It can also work with older Redmine versions starting from 4.0.0.

The plugin does not copy Redmine helper methods. It adds the CSS class `project-color-<value_id>` to `Project#css_classes` and to the links from `link_to_project`. It also adds CSS rules to the HTML head of each page.
The CSS class contains the color, for example `project-color-2b7a3e`.
The plugin shows each colored project name as a badge: text on a background in the project color.
The plugin uses white or black text, whichever has the higher [WCAG 2 contrast ratio](https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio) on the project color.
The plugin shows the badges in these places:
- The project list (board view and list view).
- The subproject list on the project overview page.
- The project list on the user page.
- The parent projects in the page header.
- The "Project" column in the issue lists and the time entry lists.
- The group headers of lists that are grouped by project (for example "My page").
- The Gantt chart, the news and the `project:` wiki links.
- The project jump box in the header.

The page header of a colored project gets the project color as background, so the project name in the header has no badge.
For a light project color, the text in the header is black.
The plugin also sets the CSS variable `--color-header-background`, which the default and the alternate Redmine themes use.
- The "Spent time" block of "My page" and the activity.

Redmine shows the project name without a link in the "Spent time" block and in the activity.
For these places the plugin uses its own copies of the partials `my/blocks/_timelog` and `activities/_activities`.
Check these copies when you update Redmine.

## Tests
Put the plugin into `<redmine_path>/plugins/redmine_project_colors` and run this command in the Redmine directory:
```sh
RAILS_ENV=test bin/rails redmine:plugins:test NAME=redmine_project_colors
```

## Installation
- Download the plugin archive and extract it to `<redmine_path>/plugins`.
- Check or rename plugin's directory to `<redmine_path>/plugins/redmine_project_colors` directory.
- Restart Redmine.
- Enjoy!

## Usage
1. Go to *Administration » Custom fields* and create a new project custom field.
2. Select the format "Color". You can give the field any name.
3. Go to the plugin settings and select the field in **Project custom field with the project color**.
4. Open the settings of a project and set the color:
   - Use the color picker, or type a hexadecimal color (`#rrggbb` or `#rgb`) in the text field.
   - The preview shows the project name with the text color that the plugin uses (white or black).
     It also shows the contrast ratio and the WCAG level (AA or AAA).
   - If neither text color reaches the contrast ratio 7:1 (WCAG level AAA), the form shows the button **Adjust contrast**.
     The button keeps the hue and the saturation, and changes the lightness as little as possible to get 7:1.
     Level AA (4.5:1) needs no button: white or black text always gives at least 4.58:1.
   - Clear the text field to remove the color.

A project without a color shows the standard colors of the theme.

## Upgrade from version 2
Version 2 used a key/value list custom field and the setting "Color Assignment" (`value_id: #color`).
Version 3 stores the color in each project. Run this task once after the upgrade:
```sh
bin/rails redmine:project_colors:migrate_to_color_field RAILS_ENV=production
```
The task does these steps:
1. It creates a new field with the format "Color" and the name of the old field.
2. It copies the color of each project from the "Color Assignment" setting.
3. It selects the new field in the plugin settings.
4. It deletes the old field.

To keep the old field for a check, set `KEEP_OLD_FIELD=1`. The task then renames it to "<name> (old)" (or to `OLD_NAME`).
The task ignores CSS color names (for example `red`). It shows a warning for each of them.

## License
This plugin is licensed under the MIT license. See LICENSE for details.
