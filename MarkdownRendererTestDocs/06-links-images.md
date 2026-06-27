# Links And Images

Inline link: [Example](https://example.com).

Inline link with title: [Example with title](https://example.com "Title text").

Relative link: [README](./README.md).

Path with spaces: [file with spaces](./some%20path/file.md).

Fragment link: [Basic blocks](./01-basic-blocks.md#h1-标题).

Reference link: [OpenAI][openai].

Collapsed reference link: [Docs][].

Shortcut reference link: [Spec].

[openai]: https://openai.com
[Docs]: https://example.com/docs
[Spec]: https://spec.commonmark.org/

Image:

![Alt text for local image](./sample-image.svg)

Image with title:

![Alt text](./sample-image-title.svg "Local image title")

Image inside link:

[![Image alt](./sample-linked-image.svg)](https://example.com)

Broken / edge links:

- [Empty destination]()
- [Just hash](#)
- [Invalid URL](ht!tp:// bad url)
- [Nested [brackets] in text](https://example.com)
- <https://example.com/autolink>
- <hello@example.com>
