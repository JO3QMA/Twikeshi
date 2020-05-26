# Twikeshi
Twitterデータからダウンロードできる"Twitter-*.zip"を使用して、直近3200件以上のツイートを消すことができます。
# DEMO
なし
# Features

- Twitter-*.zipに存在するツイートなら全て消せる。
- 除外できる条件
  - 一定期間前/後
  - 指定した数値以上のRT数のツイート
  - 指定した数値以上のFav数のツイート
  - 指定したハッシュタグを含むツイート(1つのみ)
# Requirement
 
* ruby 2.6.0
* Bundler
  * rubyzip
  * json
  * fileutils
  * twitter
  * oauth (APIキーを持ってくるスクリプトを使う場合。)

# Installation
 
```bash
bundle install --deployment
```
 
# Usage

```bash
git clone git@github.com:JO3QMA/Twikeshi.git
cd Twikeshi
ruby main.rb Twitter-*.zip
```
APIキー取得スクリプト。
```bash
ruby get_token.rb
```

# Note

- 日付はdateライブラリで扱える文字列を使用してください。
- RT/Favは-1にすると条件になりません。

# Author
 
JO3QMA
 
# License
ライセンスを明示する
 
"Twikeshi" is under [MIT license](https://en.wikipedia.org/wiki/MIT_License).