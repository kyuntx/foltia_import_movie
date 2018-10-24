# foltia ANIME Locker / import MP4-HD movie form other foltia server.

## Usage

- Install Ruby/Nokogiri
```
yum install ruby-nokogiri
```

- Save import_movie_mp4.rb to foltia server (eg. /home/foltia/tools/ )
- Add permission
```
chmod 755 /home/foltia/tools/import_movie_mp4.rb
```
- Run import_movie_mp4.rb with source foltia server CAP URI( selectcaptureimage.php?pid=XXXXX)
```
/home/foltia/tools/import_movie_mp4.rb http://foltia.example.jp/recorded/selectcaptureimage.php?pid=XXXXXX
```
- for basic authentication, add username:password@ before the hostname.
```
      /home/foltia/tools/import_movie_mp4.rb http://username:password@foltia.example.jp/recorded/selectcaptureimage.php?pid=XXXXXX
```
