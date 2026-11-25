# Redmine Project Colors Plugin

This plugin allows to set a headline color for each project according to a custom field. This project is not intended for public use, it was created
for our internal company needs. But you can use it if you want.

The plugin does not require any migration, it just adds two new fields to the Redmine administration.

This plugin is a fork of [Redmine Progressive Projects List Plugin](https://github.com/ergoserv/redmine-progressive-projects-list), although almost nothing left from the original code.

## Compatibility
The plugin is tested with Redmine 7.0.3. It can also work with older Redmine versions starting from 4.0.0.

The plugin does not copy Redmine helper methods. It adds the CSS class `project-color-<value_id>` to `Project#css_classes` and to the links from `link_to_project`. It also adds CSS rules to the HTML head of each page.
The plugin shows each colored project name as a badge: white text on a background in the project color. Use dark colors, because the text is white.
The plugin shows the badges in these places:
- The project list (board view and list view).
- The subproject list on the project overview page.
- The project list on the user page.
- The project name and the parent projects in the page header.
- The "Project" column in the issue lists and the time entry lists.
- The group headers of lists that are grouped by project (for example "My page").
- The Gantt chart, the news and the `project:` wiki links.

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
- Create a key/value list custom field for projects. You can give it any name.
- Define the list of values in the custom field settings. These values can mean anything you want.
- Go to the plugin settings and configure it:
  - **Color Field ID**: Enter your custom field ID. You can easily spot it in the URL when you edit the field properties.
  - **Color Assignment**: Define the colors for values you defined in the custom field settings:
    Each color is defined on its own line in the format `value: #color` where the `value` is the custom field value id (you will see it when you hover the *Delete* link in the custom field settings) and the `color` is a hexadecimal color code including its initial hash. For example:
	```text
	1: #ff0000
	2: #00ff00
	3: #0000ff
	```
	If you don't provide a color for a value, it will be displayed in standard color defined by your theme.
	The plugin accepts hexadecimal colors (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`) and CSS color names (for example `red`). The plugin ignores lines with a different format.

## License
This plugin is licensed under the MIT license. See LICENSE for details.
