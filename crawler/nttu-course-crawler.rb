require 'crawler_rocks'
require 'json'
require 'pry'

class NationalTaiTungUniversityCrawler

 def initialize year: nil, term: nil, update_progress: nil, after_each: nil

  @year = year-1911
  @term = term
  @update_progress_proc = update_progress
  @after_each_proc = after_each

  @query_url = "https://infosys.nttu.edu.tw/n_CourseBase_Select/CourseListPublic.aspx"
 end

 def courses
  @courses = []

  for day_night in 1..3  # 日間部、進修部、學分班

   r = RestClient.get(@query_url)
   doc = Nokogiri::HTML(r)

   hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

   # dep = Hash[doc.css('select[name="DropDownList2"] option:nth-child(n+3)').map{|opt| [opt[:value], opt.text]}]
   # dep.each do |dep_c, dep_n|

    r = post(hidden["__VIEWSTATE"], hidden["__EVENTVALIDATION"], day_night: day_night)
    doc = Nokogiri::HTML(r)

    course_temp(doc)

    next if doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td') == []

    if doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[1] != nil
     hidden = Hash[r.split('hiddenField')[1..-1].map{|hidden| [hidden.split('|')[1], hidden.split('|')[2]]}]

     r = post(hidden["__VIEWSTATE"], hidden["__EVENTVALIDATION"], toolkitScriptManager1: "UpdatePanel2|GridView1", day_night: day_night, __EVENTTARGET: "GridView1", __EVENTARGUMENT: "Page$2", button3_n: nil, button3_c: nil)
     doc = Nokogiri::HTML(r)

     course_temp(doc)
    end

    if not doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[-1] == nil
     while doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[-1].text == "..."
      for page in doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[2].text.to_i..doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[-2].text.to_i + 1
       hidden = Hash[r.split('hiddenField')[1..-1].map{|hidden| [hidden.split('|')[1], hidden.split('|')[2]]}]

       r = post(hidden["__VIEWSTATE"], hidden["__EVENTVALIDATION"], toolkitScriptManager1: "UpdatePanel2|GridView1", day_night: day_night, __EVENTTARGET: "GridView1", __EVENTARGUMENT: "Page$#{page}", button3_n: nil, button3_c: nil)
       doc = Nokogiri::HTML(r)

       course_temp(doc)
      end
     end
    end

    if not doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[2] == nil
     if page != nil
      page_check = page
     else
      page_check = 2
     end
     for page in doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[2].text.to_i..doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Pager"] td td')[-2].text.to_i + 1
      next if page <= page_check
      hidden = Hash[r.split('hiddenField')[1..-1].map{|hidden| [hidden.split('|')[1], hidden.split('|')[2]]}]

      r = post(hidden["__VIEWSTATE"], hidden["__EVENTVALIDATION"], toolkitScriptManager1: "UpdatePanel2|GridView1", day_night: day_night, __EVENTTARGET: "GridView1", __EVENTARGUMENT: "Page$#{page}", button3_n: nil, button3_c: nil)
      doc = Nokogiri::HTML(r)

      course_temp(doc)
     end
    end
   # end
  end
 # binding.pry
  @courses
 end

 def post(__VIEWSTATE, __EVENTVALIDATION, toolkitScriptManager1: "UpdatePanel1|Button3", day_night: 1, dropDownList2: "%", __EVENTTARGET: nil, __EVENTARGUMENT: nil, button3_n: "Button3", button3_c: "查詢")
  r = RestClient.post(@query_url, {
   "ToolkitScriptManager1" => toolkitScriptManager1,
   "DropDownList1" => "#{@year}#{@term}",
   "DropDownList6" => day_night,
   "DropDownList2" => dropDownList2,
   "DropDownList3" => "%",
   "DropDownList4" => "%",
   "DropDownList5" => "%",
   "DropDownList7" => "%",
   "DropDownList8" => "%",
   "TextBox6" => "0",
   "TextBox7" => "14",
   "__EVENTTARGET" => __EVENTTARGET,
   "__EVENTARGUMENT" => __EVENTARGUMENT,
   "__VIEWSTATE" => __VIEWSTATE,
   "__VIEWSTATEGENERATOR" => "5D156DDA",
   "__SCROLLPOSITIONX" => "0",
   "__SCROLLPOSITIONY" => "0",
   "__EVENTVALIDATION" => __EVENTVALIDATION,
   "__VIEWSTATEENCRYPTED" => "",
   "__ASYNCPOST" => "true",
   "#{button3_n}" => "#{button3_c}",
   }, {
    "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/43.0.2357.130 Chrome/43.0.2357.130 Safari/537.36"
    })
 end

 def course_temp(doc)
  for tr in 0..doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Row"]').count - 1
   next if doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Row"]')[tr].css('td') == nil
   data = []
   for td in 0..doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Row"]')[tr].css('td').count - 1
    data[td] = doc.css('table[class="NTTU_GridView"] tr[class="NTTU_GridView_Row"]')[tr].css('td')[td].text
   end

   course = {
    year: @year,
    term: @term,
    required: data[0],    # 修別(必選修)
    department: data[1],    # 開課系級
    course_type: data[2],    # 課程類型
    general_code: data[3],    # 課程代碼
    name: data[4],    # 課程名稱
    syllabus: data[5],    # 教學大綱
    credits: data[6],   # 學分數
    people_maximum: data[7],    # 人數上限
    people_minimum: data[8],    # 人數下限
    people_1: data[9],    # 選課人數
    people_2: data[10],    # 修課人數
    lecturer: data[11],    # 授課教師
    day: data[12],   # 上課時間說明:
                      # 11~代表星期一第1節、26~代表星期二第6節、2A~代表星期二第10節。
                      # 上課時間第1節為08:10~09:00、第6節為13:10~14:00，依此類推。
    location: data[13],    # 上課場地(人數)
    pre_course: data[14],    # 先修課程
    mix_class: data[15],    # 合班
    notes: data[16],    # 備註說明
    course_limit: data[17],    # 選課限制
    special: data[18],    # 特殊課程
    }

   @after_each_proc.call(course: course) if @after_each_proc

   @courses << course
  end
 end
end

crawler = NationalTaiTungUniversityCrawler.new(year: 2015, term: 1)
File.write('courses.json', JSON.pretty_generate(crawler.courses()))
