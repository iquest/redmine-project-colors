// Connects the color picker and the text field of the "Color" custom field
// and updates the preview with white and black text.
// The contrast calculation is the same as in lib/project_colors.rb.
(function () {
  var WHITE = '#ffffff';
  var BLACK = '#000000';

  // Returns the color in the format "#rrggbb", or null if the value is not a color.
  function normalize(value) {
    var color = value.trim().toLowerCase();
    if (/^#[0-9a-f]{3}$/.test(color)) {
      color = '#' + color[1] + color[1] + color[2] + color[2] + color[3] + color[3];
    }
    return /^#[0-9a-f]{6}$/.test(color) ? color : null;
  }

  // Returns the relative luminance of the color, as WCAG 2 defines it.
  function luminance(color) {
    var channels = [1, 3, 5].map(function (start) {
      var value = parseInt(color.substr(start, 2), 16) / 255;
      return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
  }

  function contrastRatio(color1, color2) {
    var values = [luminance(color1), luminance(color2)].sort(function (a, b) { return b - a; });
    return (values[0] + 0.05) / (values[1] + 0.05);
  }

  function bestContrast(color) {
    return Math.max(contrastRatio(color, WHITE), contrastRatio(color, BLACK));
  }

  function toHsl(color) {
    var rgb = [1, 3, 5].map(function (start) { return parseInt(color.substr(start, 2), 16) / 255; });
    var max = Math.max.apply(null, rgb);
    var min = Math.min.apply(null, rgb);
    var lightness = (max + min) / 2;
    var delta = max - min;
    if (delta === 0) return [0, 0, lightness];

    var saturation = delta / (1 - Math.abs(2 * lightness - 1));
    var hue;
    if (max === rgb[0]) hue = ((rgb[1] - rgb[2]) / delta) % 6;
    else if (max === rgb[1]) hue = (rgb[2] - rgb[0]) / delta + 2;
    else hue = (rgb[0] - rgb[1]) / delta + 4;
    return [(hue * 60 + 360) % 360, saturation, lightness];
  }

  function fromHsl(hue, saturation, lightness) {
    var chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
    var x = chroma * (1 - Math.abs((hue / 60) % 2 - 1));
    var m = lightness - chroma / 2;
    var sector = Math.floor(hue / 60) % 6;
    var rgb = [[chroma, x, 0], [x, chroma, 0], [0, chroma, x], [0, x, chroma], [x, 0, chroma], [chroma, 0, x]][sector];
    return '#' + rgb.map(function (value) {
      var channel = Math.round((value + m) * 255);
      return ('0' + Math.min(255, Math.max(0, channel)).toString(16)).slice(-2);
    }).join('');
  }

  // Returns the color with the same hue and saturation and the nearest lightness
  // that gives white or black text the minimum contrast. A binary search finds the lightness.
  function adjustContrast(color, minContrast) {
    var hsl = toHsl(color);
    var candidates = [[WHITE, 0, hsl[2]], [BLACK, hsl[2], 1]].map(function (option) {
      var text = option[0];
      var good = text === WHITE ? option[1] : option[2];
      var bad = text === WHITE ? option[2] : option[1];
      for (var i = 0; i < 30; i++) {
        var middle = (good + bad) / 2;
        if (contrastRatio(fromHsl(hsl[0], hsl[1], middle), text) >= minContrast) good = middle;
        else bad = middle;
      }
      // The conversion to "#rrggbb" rounds the channels. Move a small step more if the rounded color fails.
      var step = text === WHITE ? -0.002 : 0.002;
      var result = fromHsl(hsl[0], hsl[1], good);
      while (contrastRatio(result, text) < minContrast && good > 0 && good < 1) {
        good = Math.min(1, Math.max(0, good + step));
        result = fromHsl(hsl[0], hsl[1], good);
      }
      return { color: result, change: Math.abs(good - hsl[2]) };
    });
    return candidates[0].change <= candidates[1].change ? candidates[0].color : candidates[1].color;
  }

  function minContrast(wrapper) {
    return parseFloat(wrapper.getAttribute('data-min-contrast')) || 7;
  }

  function update(wrapper, color, source) {
    var picker = wrapper.querySelector('.project-colors-picker');
    var code = wrapper.querySelector('.project-colors-code');
    var preview = wrapper.querySelector('.project-colors-preview');
    var adjust = wrapper.querySelector('.project-colors-adjust');
    if (color && source !== picker) picker.value = color;
    if (source !== code) code.value = color;
    preview.hidden = !color;
    adjust.hidden = !color || bestContrast(color) >= minContrast(wrapper);
    if (!color) return;

    var text = contrastRatio(color, WHITE) >= contrastRatio(color, BLACK) ? WHITE : BLACK;
    var ratio = contrastRatio(color, text);
    var level = contrastLevel(ratio, minContrast(wrapper));
    var badge = preview.querySelector('.project-colors-badge');
    badge.style.backgroundColor = color;
    badge.style.color = text;
    preview.querySelector('.project-colors-text').textContent =
      preview.getAttribute(text === WHITE ? 'data-label-white' : 'data-label-black');
    preview.querySelector('.project-colors-ratio').textContent = ratio.toFixed(1) + ':1';
    var levelTag = preview.querySelector('.project-colors-level');
    levelTag.textContent = level;
    levelTag.className = 'project-colors-level project-colors-level-' + level.toLowerCase();
  }

  // Returns the WCAG 2 level of normal text, as ProjectColors.contrast_level does.
  function contrastLevel(ratio, aaaRatio) {
    if (ratio >= aaaRatio) return 'AAA';
    if (ratio >= 4.5) return 'AA';
    return '';
  }

  function onChange(event) {
    var target = event.target;
    var wrapper = target.closest && target.closest('.project-colors-input');
    if (!wrapper) return;

    if (target.classList.contains('project-colors-picker')) {
      update(wrapper, target.value, target);
    } else if (target.classList.contains('project-colors-code')) {
      update(wrapper, normalize(target.value), target);
    }
  }

  // Some color dialogs send only a "change" event when they close, and no "input" events.
  document.addEventListener('input', onChange);
  document.addEventListener('change', onChange);

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('.project-colors-adjust');
    if (!button) return;

    var wrapper = button.closest('.project-colors-input');
    var color = normalize(wrapper.querySelector('.project-colors-code').value);
    if (color) update(wrapper, adjustContrast(color, minContrast(wrapper)), button);
  });
})();
