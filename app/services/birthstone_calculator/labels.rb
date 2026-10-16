# frozen_string_literal: true

class BirthstoneCalculator
  # Interface strings for the calculator in English, Hindi and Bengali.
  # The key labels and every stone, sign and month name are translated; long
  # explanatory copy mostly stays English (see Labels.t fallbacks).
  #
  # Hindi and Bengali strings were written for this tool and should be read
  # by a native speaker before they are treated as final.
  module Labels
    module_function

    STRINGS = {
      title: { en: "Birthstone & Navaratna Calculator", hi: "जन्मरत्न और नवरत्न कैलकुलेटर", bn: "জন্মরত্ন ও নবরত্ন ক্যালকুলেটর" },
      language: { en: "Language", hi: "भाषा", bn: "ভাষা" },
      dob: { en: "Date of birth", hi: "जन्म तिथि", bn: "জন্মতারিখ" },
      rashi_select: { en: "Your rashi (Moon sign), if you know it", hi: "आपकी राशि (चंद्र राशि), यदि पता हो", bn: "আপনার রাশি (চন্দ্র রাশি), যদি জানা থাকে" },
      rashi_unknown: { en: "Not sure: estimate from my date", hi: "पता नहीं: तिथि से अनुमान लगाएँ", bn: "জানি না: তারিখ থেকে অনুমান করুন" },
      submit: { en: "Show my stones", hi: "मेरे रत्न देखें", bn: "আমার রত্ন দেখুন" },
      copy_link: { en: "Copy link to this result", hi: "इस परिणाम का लिंक कॉपी करें", bn: "এই ফলাফলের লিংক কপি করুন" },
      copied: { en: "Link copied", hi: "लिंक कॉपी हो गया", bn: "লিংক কপি হয়েছে" },

      your_birthstone: { en: "Your birthstone", hi: "आपका जन्मरत्न", bn: "আপনার জন্মরত্ন" },
      born_in: { en: "Born in %{month}", hi: "%{month} में जन्म", bn: "%{month} মাসে জন্ম" },
      modern: { en: "Modern list", hi: "आधुनिक सूची", bn: "আধুনিক তালিকা" },
      modern_by: { en: "American Gem Trade Association and Jewelers of America", hi: "अमेरिकन जेम ट्रेड एसोसिएशन और ज्वेलर्स ऑफ़ अमेरिका", bn: "আমেরিকান জেম ট্রেড অ্যাসোসিয়েশন ও জুয়েলার্স অব আমেরিকা" },
      traditional: { en: "Traditional list", hi: "पारंपरिक सूची", bn: "ঐতিহ্যবাহী তালিকা" },
      traditional_by: { en: "the pre-1912 list", hi: "1912 से पहले की सूची", bn: "১৯১২-এর আগের তালিকা" },
      also_seen: { en: "Also sold as a birthstone", hi: "जन्मरत्न के रूप में भी बिकता है", bn: "জন্মরত্ন হিসেবেও বিক্রি হয়" },

      your_zodiac: { en: "Your zodiac stones", hi: "आपकी पश्चिमी राशि के रत्न", bn: "আপনার পাশ্চাত্য রাশির রত্ন" },
      sun_sign: { en: "Western Sun sign", hi: "पश्चिमी सूर्य राशि", bn: "পাশ্চাত্য সূর্য রাশি" },
      ruled_by: { en: "ruled by %{planet}", hi: "स्वामी: %{planet}", bn: "অধিপতি: %{planet}" },
      show_all: { en: "Show all %{n} stones", hi: "सभी %{n} रत्न देखें", bn: "সব %{n}টি রত্ন দেখুন" },
      why_ruler: { en: "its planet matches the sign's ruler", hi: "इसका ग्रह राशि के स्वामी से मेल खाता है", bn: "এর গ্রহ রাশির অধিপতির সঙ্গে মেলে" },
      why_element: { en: "shares the sign's element", hi: "राशि के तत्व से मेल", bn: "রাশির তত্ত্বের সঙ্গে মিল" },
      why_birthstone: { en: "also your birth-month stone", hi: "आपके जन्म-माह का रत्न भी", bn: "আপনার জন্মমাসের রত্নও" },
      why_listed: { en: "tradition lists this sign", hi: "परंपरा में यह राशि सूचीबद्ध है", bn: "ঐতিহ্যে এই রাশি তালিকাভুক্ত" },
      cusp: { en: "Your Sun was within a degree of the %{a}/%{b} boundary. Your exact sign depends on your birth time and place; read both.", hi: "आपका सूर्य %{a}/%{b} की सीमा के एक अंश के भीतर था। सही राशि जन्म समय और स्थान पर निर्भर करती है; दोनों पढ़ें।", bn: "আপনার সূর্য %{a}/%{b} সীমারেখার এক ডিগ্রির মধ্যে ছিল। সঠিক রাশি জন্মসময় ও স্থানের ওপর নির্ভর করে; দুটিই পড়ুন।" },
      caution_for_sign: { en: "Tradition advises caution", hi: "परंपरा सावधानी की सलाह देती है", bn: "ঐতিহ্য সতর্কতার পরামর্শ দেয়" },

      your_vedic: { en: "Your Vedic ratna", hi: "आपका वैदिक रत्न (नवरत्न)", bn: "আপনার বৈদিক রত্ন (নবরত্ন)" },
      rashi: { en: "Rashi", hi: "राशि", bn: "রাশি" },
      rashi_lord: { en: "Rashi lord", hi: "राशि स्वामी", bn: "রাশির অধিপতি" },
      ratna: { en: "Ratna", hi: "रत्न", bn: "রত্ন" },
      substitutes: { en: "Substitutes (upratna)", hi: "उपरत्न (विकल्प)", bn: "উপরত্ন (বিকল্প)" },
      avoid: { en: "Stones Vedic tradition advises against", hi: "वैदिक परंपरा जिन रत्नों से बचने की सलाह देती है", bn: "বৈদিক ঐতিহ্য যে রত্নগুলি এড়াতে পরামর্শ দেয়" },
      estimate: { en: "Estimate", hi: "अनुमान", bn: "অনুমান" },
      your_choice: { en: "Your selection", hi: "आपका चयन", bn: "আপনার নির্বাচন" },
      approx_note: {
        en: "This rashi is an estimate. It is the sidereal (Lahiri) sign the Sun was in on your date. Jyotish normally uses your Moon sign (janma rashi) or ascendant (lagna), which need your birth time and place. If you know your rashi, select it above.",
        hi: "यह राशि केवल अनुमान है। यह आपकी तिथि पर सूर्य की निरयन (लाहिरी) राशि है। ज्योतिष में आमतौर पर चंद्र राशि (जन्म राशि) या लग्न देखा जाता है, जिसके लिए जन्म समय और स्थान चाहिए। यदि आपको अपनी राशि पता है, तो ऊपर चुनें।",
        bn: "এই রাশি একটি অনুমান। এটি আপনার তারিখে সূর্য যে নিরয়ণ (লাহিড়ী) রাশিতে ছিল সেটি। জ্যোতিষে সাধারণত চন্দ্র রাশি (জন্ম রাশি) বা লগ্ন দেখা হয়, যার জন্য জন্মসময় ও স্থান লাগে। আপনার রাশি জানা থাকলে ওপরে বেছে নিন।"
      },
      selected_note: {
        en: "Using the rashi you selected. Astrologers usually weigh the whole birth chart, so the lord of your rashi is a starting point for a conversation, not a prescription.",
        hi: "आपकी चुनी हुई राशि का उपयोग किया गया है। ज्योतिषी आमतौर पर पूरी कुंडली देखते हैं, इसलिए राशि स्वामी केवल शुरुआती संकेत है, निर्देश नहीं।",
        bn: "আপনার বেছে নেওয়া রাশি ব্যবহার করা হয়েছে। জ্যোতিষীরা সাধারণত পুরো জন্মকুণ্ডলী দেখেন, তাই রাশির অধিপতি শুধু একটি সূচনা, নির্দেশ নয়।"
      },
      chain: {
        en: "%{rashi} is ruled by %{lord}. Jyotish pairs %{lord} with %{ratna}.",
        hi: "%{rashi} के स्वामी %{lord} हैं। ज्योतिष में %{lord} का रत्न %{ratna} है।",
        bn: "%{rashi} রাশির অধিপতি %{lord}। জ্যোতিষে %{lord} গ্রহের রত্ন %{ratna}।"
      },
      caution_title: { en: "Before you buy a ratna", hi: "रत्न खरीदने से पहले", bn: "রত্ন কেনার আগে" },
      caution_astrologer: {
        en: "Tradition says a ratna should be worn on the advice of an astrologer who has read your full chart, not chosen from a sign alone. Many practitioners look at the ascendant lord or the current planetary period (dasha) rather than the Moon sign lord.",
        hi: "परंपरा कहती है कि रत्न केवल राशि देखकर नहीं, बल्कि पूरी कुंडली पढ़ने वाले ज्योतिषी की सलाह से पहनना चाहिए। कई ज्योतिषी राशि स्वामी की जगह लग्नेश या चल रही दशा देखते हैं।",
        bn: "ঐতিহ্য বলে, রত্ন শুধু রাশি দেখে নয়, পুরো কুণ্ডলী পড়েছেন এমন জ্যোতিষীর পরামর্শে পরা উচিত। অনেক জ্যোতিষী চন্দ্র রাশির অধিপতির বদলে লগ্নাধিপতি বা চলতি দশা দেখেন।"
      },
      caution_trial: {
        en: "Precious ratnas, above all Neelam (blue sapphire), are traditionally tried for a few days before they are set permanently, for example worn loosely or kept close, and dropped if the wearer is uneasy. Practices differ between lineages.",
        hi: "कीमती रत्न, विशेषकर नीलम, परंपरा में स्थायी रूप से जड़वाने से पहले कुछ दिन आज़माए जाते हैं, और असहज लगने पर छोड़ दिए जाते हैं। अलग-अलग परंपराओं में नियम अलग हैं।",
        bn: "দামি রত্ন, বিশেষ করে নীলা, ঐতিহ্য অনুযায়ী স্থায়ীভাবে বসানোর আগে কয়েকদিন পরীক্ষা করে দেখা হয়, অস্বস্তি হলে ছেড়ে দেওয়া হয়। ধারা ভেদে নিয়ম আলাদা।"
      },
      caution_malefic: {
        en: "%{ratna} belongs to %{graha}, a planet Jyotish texts treat as a hard taskmaster. This is the stone tradition says to be most careful with.",
        hi: "%{ratna} %{graha} का रत्न है, जिसे ज्योतिष ग्रंथ कठोर ग्रह मानते हैं। परंपरा इस रत्न के साथ सबसे अधिक सावधानी बरतने को कहती है।",
        bn: "%{ratna} হল %{graha} গ্রহের রত্ন, যে গ্রহকে জ্যোতিষ গ্রন্থ কঠোর গ্রহ মনে করে। ঐতিহ্য এই রত্নে সবচেয়ে বেশি সতর্ক থাকতে বলে।"
      },
      caution_quality: {
        en: "Gem quality and treatment matter more than the label. Ask for a lab report that states whether the stone is natural and whether it is heated, dyed or filled.",
        hi: "रत्न की गुणवत्ता और उपचार नाम से ज़्यादा मायने रखते हैं। लैब रिपोर्ट माँगें, जिसमें लिखा हो कि रत्न प्राकृतिक है या नहीं और उसे गर्म, रंगा या भरा गया है या नहीं।",
        bn: "নামের চেয়ে রত্নের মান ও শোধন বেশি গুরুত্বপূর্ণ। ল্যাব রিপোর্ট চান, যাতে লেখা থাকে রত্নটি প্রাকৃতিক কিনা এবং তাতে তাপ, রং বা ফিলিং দেওয়া হয়েছে কিনা।"
      },
      no_enemies: {
        en: "Classical tables name no natural enemy for the Moon, so this tradition lists no stone to avoid on that basis. An astrologer will still look at the whole chart.",
        hi: "शास्त्रीय तालिकाओं में चंद्र का कोई नैसर्गिक शत्रु नहीं बताया गया है, इसलिए इस आधार पर बचने वाला कोई रत्न नहीं है। फिर भी ज्योतिषी पूरी कुंडली देखते हैं।",
        bn: "শাস্ত্রীয় তালিকায় চন্দ্রের কোনো নৈসর্গিক শত্রু নেই, তাই এই ভিত্তিতে এড়ানোর মতো কোনো রত্ন নেই। তবুও জ্যোতিষী পুরো কুণ্ডলী দেখেন।"
      },
      enemy_reason: {
        en: "In Jyotish, %{lord} treats %{enemy} as a natural enemy (naisargika shatru), so the stone of %{enemy} is traditionally not worn with %{ratna}.",
        hi: "ज्योतिष में %{lord}, %{enemy} को नैसर्गिक शत्रु मानता है, इसलिए %{enemy} का रत्न परंपरा में %{ratna} के साथ नहीं पहना जाता।",
        bn: "জ্যোতিষে %{lord} গ্রহ %{enemy} গ্রহকে নৈসর্গিক শত্রু মানে, তাই ঐতিহ্য অনুযায়ী %{ratna} ও %{enemy} গ্রহের রত্ন একসঙ্গে পরা হয় না।"
      },

      your_weekday: { en: "Your weekday stone", hi: "आपके जन्म-वार का रत्न", bn: "আপনার জন্মবারের রত্ন" },
      born_on: { en: "Born on a %{day}", hi: "जन्म का वार: %{day}", bn: "জন্মবার: %{day}" },
      weekday_planet: { en: "Ruling planet", hi: "वार का ग्रह", bn: "বারের গ্রহ" },
      weekday_note: {
        en: "In Hindu tradition the day (vara) begins at sunrise, so someone born in the early hours before sunrise is counted under the previous weekday.",
        hi: "हिंदू परंपरा में वार सूर्योदय से शुरू होता है, इसलिए सूर्योदय से पहले जन्मे व्यक्ति का वार पिछला दिन माना जाता है।",
        bn: "হিন্দু ঐতিহ্যে বার সূর্যোদয় থেকে শুরু হয়, তাই সূর্যোদয়ের আগে জন্মালে আগের দিনের বার ধরা হয়।"
      },
      read_more: { en: "Read the %{stone} guide", hi: "%{stone} की जानकारी पढ़ें", bn: "%{stone}-এর গাইড পড়ুন" },
      tradition: { en: "Tradition, not science", hi: "परंपरा, विज्ञान नहीं", bn: "ঐতিহ্য, বিজ্ঞান নয়" },
      tradition_short: {
        en: "These associations come from birthstone lists, Western astrology and Jyotish. They are traditions people value, not scientific claims, and no stone replaces medical care.",
        hi: "ये संबंध जन्मरत्न सूचियों, पश्चिमी ज्योतिष और वैदिक ज्योतिष की परंपरा से आते हैं। ये वैज्ञानिक दावे नहीं हैं, और कोई रत्न चिकित्सा का विकल्प नहीं है।",
        bn: "এই সম্পর্কগুলি জন্মরত্নের তালিকা, পাশ্চাত্য জ্যোতিষ ও বৈদিক জ্যোতিষের ঐতিহ্য থেকে আসে। এগুলি বৈজ্ঞানিক দাবি নয়, এবং কোনো রত্নই চিকিৎসার বিকল্প নয়।"
      },
      all_months: { en: "Birthstones for every month", hi: "हर माह के जन्मरत्न", bn: "প্রতি মাসের জন্মরত্ন" },
      chart_title: { en: "Rashi and ratna chart", hi: "राशि और रत्न तालिका", bn: "রাশি ও রত্ন তালিকা" },
      only_rashi: { en: "Showing your Vedic ratna from the rashi you selected. Add your date of birth for the birthstone, zodiac and weekday cards.", hi: "आपकी चुनी हुई राशि से वैदिक रत्न दिखाया गया है। जन्मरत्न, राशि और वार के कार्ड के लिए जन्म तिथि जोड़ें।", bn: "আপনার বেছে নেওয়া রাশি থেকে বৈদিক রত্ন দেখানো হয়েছে। জন্মরত্ন, রাশি ও বারের কার্ডের জন্য জন্মতারিখ যোগ করুন।" },
      no_atlas: { en: "No page for this stone yet", hi: "इस रत्न का पेज अभी नहीं है", bn: "এই রত্নের পেজ এখনও নেই" }
    }.freeze

    ELEMENTS = {
      "fire" => { en: "Fire", hi: "अग्नि", bn: "অগ্নি" }, "earth" => { en: "Earth", hi: "पृथ्वी", bn: "পৃথিবী" },
      "air" => { en: "Air", hi: "वायु", bn: "বায়ু" }, "water" => { en: "Water", hi: "जल", bn: "জল" }
    }.freeze

    def element(name, lang = "en")
      row = ELEMENTS[name.to_s] or return name.to_s.capitalize
      row[lang.to_s.to_sym] || row[:en]
    end

    # True when `key` has its own text in `lang` (not an English fallback).
    def has?(key, lang)
      row = STRINGS[key.to_sym]
      !row.nil? && !row[lang.to_s.to_sym].to_s.empty?
    end

    def t(key, lang = "en", **vars)
      row = STRINGS[key.to_sym] or return key.to_s
      text = row[lang.to_s.to_sym]
      text = row[:en] if text.nil? || text.empty?
      vars.empty? ? text : format(text, vars.transform_keys(&:to_sym))
    end
  end
end
