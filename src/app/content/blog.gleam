//// Edit this module to publish articles and share YouTube videos.

pub type Post {
  Post(
    slug: String,
    title: String,
    category: String,
    excerpt: String,
    date: String,
    minutes: String,
    body: String,
  )
}

pub type Video {
  Video(
    id: String,
    title: String,
    creator: String,
    category: String,
    note: String,
  )
}

pub fn posts() -> List(Post) {
  [
    Post(
      "gleam-first-steps",
      "Gleam နဲ့ functional programming ကို စတင်လေ့လာမယ်",
      "Gleam",
      "Type safety၊ immutable data နဲ့ pattern matching — Gleam ရဲ့ အခြေခံတွေကို code အတိုလေးတွေနဲ့ လေ့လာကြမယ်။",
      "12 Oct 2026",
      "5 min read",
      "<p>Gleam က static type system ပါဝင်တဲ့ functional programming language တစ်ခုပါ။ Variable တစ်ခုရဲ့ type ကို compiler က စစ်ပေးတာကြောင့် program မ run ခင်မှာ အမှားတချို့ကို တွေ့နိုင်ပါတယ်။</p><h2>ပထမဆုံး function</h2><pre><code>pub fn greet(name: String) -&gt; String {\n  \"မင်္ဂလာပါ၊ \" &lt;&gt; name\n}</code></pre><p>ဒီ function က String ကို လက်ခံပြီး String ပြန်ပေးပါတယ်။ &lt;&gt; က string နှစ်ခုကို ဆက်ပေးတဲ့ operator ပါ။</p><h2>Pattern matching နဲ့ error ကို ကိုင်တွယ်မယ်</h2><pre><code>import gleam/int\n\ncase int.parse(\"42\") {\n  Ok(number) -&gt; number + 1\n  Error(_) -&gt; 0\n}</code></pre><p>Result ရဲ့ Ok နဲ့ Error နှစ်မျိုးလုံးကို ကိုင်တွယ်ပေးထားပါတယ်။ မပြောင်းလဲတဲ့ data နဲ့ ရှင်းလင်းတဲ့ function တွေကို အသုံးပြုခြင်းက code ကို နားလည်ရလွယ်စေပါတယ်။</p><h2>ကိုယ်တိုင် စမ်းကြည့်ပါ</h2><p>greet function ကို ရေးပြီး ကိုယ့်နာမည်နဲ့ ခေါ်ကြည့်ပါ။ ပြီးရင် int.parse ကို number မဟုတ်တဲ့ string ပေးပြီး Error branch ကို စမ်းကြည့်ပါ။</p><p><a href=\"https://tour.gleam.run/\" target=\"_blank\" rel=\"noopener noreferrer\">Gleam language tour ↗</a></p>",
    ),
    Post(
      "git-everyday",
      "နေ့တိုင်း အသုံးဝင်မယ့် Git workflow",
      "Tools",
      "ပြောင်းလဲမှုတွေကို စစ်မယ်၊ commit သေးသေးလေးတွေ လုပ်မယ်၊ branch တစ်ခုနဲ့ feature အသစ်ကို စမ်းမယ်။",
      "12 Oct 2026",
      "4 min read",
      "<p>Git သုံးတဲ့အခါ အရေးကြီးဆုံးက ကိုယ်ဘာကို သိမ်းထားလဲဆိုတာ နားလည်နေဖို့ပါ။ Command တွေကို မ run ခင် working tree ကို အရင်ကြည့်ပါ။</p><h2>ပြောင်းလဲထားတဲ့ ဖိုင်တွေကို စစ်ပါ</h2><pre><code>git status\ngit diff</code></pre><p>git status က ပြောင်းလဲထားတဲ့ ဖိုင်တွေကို ပြပေးပါတယ်။ git diff က ဖိုင်အတွင်း ဘယ် line တွေ ပြောင်းထားလဲဆိုတာ ပြပေးပါတယ်။</p><h2>Feature တစ်ခု၊ branch တစ်ခု</h2><pre><code>git switch -c feature/blog-search\n# edit your files\ngit add src/resources/ts/app.ts\ngit diff --staged\ngit commit -m \"Add blog search\"</code></pre><p>ဆက်စပ်တဲ့ ပြောင်းလဲမှုတွေကို commit တစ်ခုအဖြစ် သိမ်းပါ။ Commit message မှာ ဘာပြောင်းထားလဲဆိုတာ ရှင်းရှင်းလင်းလင်း ရေးပါ။</p><h2>မသိမ်းသင့်တဲ့ ဖိုင်တွေ</h2><p>.env ထဲက secret တွေ၊ node_modules နဲ့ local database တွေကို .gitignore ထဲမှာ ထည့်ထားပါ။ Commit မလုပ်ခင် staged diff ကို ပြန်ဖတ်တဲ့ အလေ့အကျင့် လုပ်ပါ။</p><p><a href=\"https://git-scm.com/docs\" target=\"_blank\" rel=\"noopener noreferrer\">Git documentation ↗</a></p>",
    ),
    Post(
      "web-request-basics",
      "Browser ကနေ server ဆီ — HTTP ကို နားလည်မယ်",
      "Web development",
      "URL တစ်ခုဖွင့်လိုက်တဲ့အခါ request နဲ့ response က ဘယ်လို အလုပ်လုပ်လဲ။",
      "12 Oct 2026",
      "3 min read",
      "<p>Browser မှာ URL တစ်ခုဖွင့်လိုက်တဲ့အခါ server ဆီ HTTP request ပို့ပါတယ်။ Server က status code၊ headers နဲ့ body ပါတဲ့ response ကို ပြန်ပို့ပါတယ်။</p><h2>Request နဲ့ response</h2><pre><code>GET /api/welcome HTTP/1.1\nHost: localhost:8000\n\nHTTP/1.1 200 OK\nContent-Type: application/json\n\n\"Welcome to Glimr ✨\"</code></pre><p>GET က resource ကို တောင်းယူတာပါ။ HTML page ဆိုရင် browser က render လုပ်ပေးပါတယ်။ JSON ဆိုရင် frontend code က data အဖြစ် အသုံးပြုနိုင်ပါတယ်။</p><h2>Status code တွေ</h2><p>200 က request အောင်မြင်တာ၊ 404 က resource မတွေ့တာ၊ 500 က server ဘက်မှာ error ဖြစ်တာကို ပြပါတယ်။ Response status ကို စစ်တာက debugging ရဲ့ ကောင်းမွန်တဲ့ အစတစ်ခုပါ။</p><h2>ကိုယ်တိုင် ကြည့်ကြမယ်</h2><p>Browser ရဲ့ Developer Tools မှာ Network tab ကို ဖွင့်ပြီး page ကို reload လုပ်ပါ။ Request တစ်ခုကို ရွေးပြီး method၊ status နဲ့ response ကို ကြည့်ပါ။</p><pre><code>curl -i http://localhost:8000/api/welcome</code></pre>",
    ),
  ]
}

pub fn videos() -> List(Video) {
  [
    Video(
      "2WtPyqwTLKM",
      "CS50x 2025 · Lecture 0: Scratch",
      "CS50 / Harvard",
      "Fundamentals",
      "Computer science ကို စတင်လေ့လာဖို့။ English video ဖြစ်ပါတယ်။",
    ),
    Video(
      "RGOj5yH7evk",
      "Git and GitHub for Beginners",
      "freeCodeCamp.org",
      "Tools",
      "Git အခြေခံနဲ့ GitHub workflow ကို အတူတူ လေ့ကျင့်ကြမယ်။ English video ဖြစ်ပါတယ်။",
    ),
  ]
}
