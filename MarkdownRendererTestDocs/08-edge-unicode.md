# Edge Cases And Unicode

中文段落：这是一段较长的中文文本，用于观察自动换行、行高、标点挤压、字体 fallback 和选择复制效果是否正常。

Emoji: 😀 😅 🚀 ✅ ❌ ❤️ 👨‍👩‍👧‍👦

组合字符：é 和 é 看起来相似，但 Unicode 表示不同。

全角字符：ＡＢＣ１２３，半角字符：ABC123。

RTL text:

مرحبا بالعالم

Mixed direction: English العربية English 123.

Zero width characters around this word: a​b‌c‍d

Non-breaking spaces: A B C

Tabs in paragraph:

Column A	Column B	Column C

Very long word:

aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

Very long URL:

https://example.com/this/is/a/very/long/path/that/should/wrap/or/scroll/in/a/reasonable/way/without/breaking/the/layout/or/pushing/the/container/offscreen?query=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz

Escaped entities:

&amp; &lt; &gt; &quot; &#39;

Raw angle brackets:

1 < 2 and 3 > 2

Repeated blank lines follow:




After multiple blank lines.
