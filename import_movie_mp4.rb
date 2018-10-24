#!/bin/env ruby
# encoding: utf-8

# import mp4 movie form other foltia server

# 依存ライブラリ類
# CentOS 6.10 ベースの foltia では事前に以下をインストール
# yum install ruby-nokogiri
require 'open-uri'
require 'nokogiri'

# TSファイル保存先
TS_DIR="/home/foltia/php/tv/"

# 各要素のXpath (Chrome, FirefoxのF12などで調べる）
XPATH_TS="//*[@id=\"programInfo\"]/p[3]/a[1]"
XPATH_MP4='//*[@id="programInfo"]/p[3]/a[2]'
XPATH_CAP='//*[@id="captureList"]/li'

# wget ダウンロード用関数
def wget_download(uri, dest, http_user, http_pass, opt = "")
  if !http_user.empty? && !http_pass.empty? 
    opt = opt + " --http-user=#{http_user} --http-passwd=#{http_pass}"
  end
  system "wget #{opt} -O #{dest} #{uri}"
  if status = $? # Process::Status
    if not status.success?
      raise "wget download failed (uri=#{uri} dest=#{dest} status=#{status.to_i} pid=#{status.pid})"
    end
  end
end

# PostgreSQL操作用関数
def psql_query(sql)
  system "psql foltia -c \"#{sql}\""
  if status = $? # Process::Status
    if not status.success?
      raise "psql query failed (status=#{status.to_i} pid=#{status.pid})"
    end
  end
end

# 引数チェック
if ARGV.length == 0 || !ARGV[0].include?("selectcaptureimage") then
  puts "usage: import_movie_mp4.rb http://source.foltia.server/recorded/selectcaptureimage.php?pid=xxxxxxx"
  puts "       for basic authentication http://username:password@source.foltia.server/recorded/seletcaptureimage.php?pid=xxxxxxxx"
  exit
end

# HTMLの読み込み
uri = ARGV[0]
http_user = ""
http_pass = ""

# Basic認証を書けている場合の対応
if uri =~ /http:\/\/(.*?):(.*?)@(.*)$/
  http_user = $1
  http_pass = $2
  uri       = "http://#{$3}"
end

print "* Get Capture image HTML from #{uri}\n"
print "  basic authentication enabled, id: #{http_user}, pass: ********\n" if !http_user.empty? && !http_pass.empty?

charset = nil
html = open(uri, :http_basic_authentication => [http_user, http_pass]) do |f|
  charset = f.charset
  f.read
end

# HTMLのスクレイピング
print "* HTML scraping ... \n"

doc          = Nokogiri::HTML.parse(html, nil, charset)
baseuri      = uri.gsub(/\/recorded\/selectcaptureimage\.php\?pid=.*$/,"") 
tsfile       = doc.xpath(XPATH_TS).attribute("href").value.gsub("/tv/","")
mp4uri       = baseuri+ doc.xpath(XPATH_MP4).attribute("href").value
mp4file      = doc.xpath(XPATH_MP4).attribute("href").value.gsub(/\/tv\/\d*?\.localized\/mp4\//,"")
basefilename = mp4file[/MHD-(.*)\.MP4/,1]
pid          = uri[/pid=(.*)$/,1]
tid          = doc.xpath(XPATH_MP4).attribute("href").value[/\/tv\/(\d*?)\.localized\/mp4\//,1]
mp4dir       = "#{TS_DIR}#{tid}.localized/mp4/"
imgdir       = "#{TS_DIR}#{tid}.localized/img/#{basefilename}/"
thmuri       = "#{baseuri}/tv/#{tid}.localized/mp4/MAQ-#{basefilename}.THM"
thmfile      = "#{mp4dir}MAQ-#{basefilename}.THM"

print "  MP4URI: #{mp4uri}\n  MP4FILE: #{mp4file}\n  PID:#{pid}\n  TID:#{tid}\n  MP4DIR:#{mp4dir}\n  IMGDIR:#{imgdir}\n  THMURI:#{thmuri}\n  THMFILE:#{thmfile}\n"

# ディレクトリがなければ作る
print "* Create Directory.\n"

system "mkdir -p #{mp4dir}"
system "mkdir -p #{imgdir}"

# MP4 ダウンロード
print "* Download MP4-HD file : #{mp4uri}\n"
wget_download(mp4uri, "#{mp4dir}#{mp4file}", http_user, http_pass)

# サムネイルのダウンロード
print "* Download THM file : #{thmuri}\n"
wget_download(thmuri, thmfile, http_user, http_pass, "-q")

# キャプチャ画像のダウンロード（存在しないときはどうなるか不明）
print "* Download Capture files\n"
doc.xpath(XPATH_CAP).each do |node|
  imgfile = node.css("img").attribute("src").value[/(\d*)\.jpg/,1] + ".jpg"
  imguri  = "#{baseuri}/tv/#{tid}.localized/img/#{basefilename}/#{imgfile}"
  imgpath = "#{imgdir}#{imgfile}"
  print "  #{imgfile}\n"
  wget_download(imguri, imgpath,  http_user, http_pass, "-q")
end

# MP4ファイルのDB登録
print "* Add MP4-HD file to DB. \n"
psql_query("insert into foltia_hdmp4files (tid,hdmp4filename) values (#{tid},'#{mp4file}');")

# subtitle DBの更新
print "* Update foltia_subtitle DB. \n"
psql_query("update foltia_subtitle set m2pfilename='#{tsfile}', mp4hd='#{mp4file}', filestatus=200 where pid=#{pid};")

# DLNAストラクチャの生成
print "* Update DLNA structure.\n"
system "/home/foltia/perl/makedlnastructure.pl #{mp4file}"
if status = $? # Process::Status
  if not status.success?
    raise "update make dlna symlink failed (status=#{status.to_i} pid=#{status.pid})"
  end
end

print "* done.\n"

# - eof -
