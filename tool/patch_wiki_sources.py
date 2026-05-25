#!/usr/bin/env python3
"""Patch wiki packs: locale-native CPR/AED sources + Sources on every article."""

import json
from pathlib import Path

IFRC_URL = (
    "https://www.ifrc.org/sites/default/files/2026-03/"
    "IFRC%20International%20First%20Aid%2C%20Resuscitation%20and%20Education%20"
    "Guidelines%202025.pdf"
)

SOURCES_HEADER = {
    "en": "## Sources",
    "de": "## Quellen",
    "es": "## Fuentes",
    "fr": "## Sources",
    "el": "## Πηγές",
    "ar": "## المصادر",
    "zh": "## 来源",
}

# Shared source lines (English titles; URLs are universal).
ARTICLE_SOURCES = {
    "general_safety": [
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — general approach and scene safety.",
            IFRC_URL,
        ),
    ],
    "evacuation": [
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — disaster preparedness.",
            IFRC_URL,
        ),
        (
            "U.S. Department of Homeland Security. Evacuation.",
            "https://www.ready.gov/evacuation",
        ),
    ],
    "first_aid_bleeding": [
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — severe bleeding.",
            IFRC_URL,
        ),
    ],
    "fire_smoke": [
        (
            "U.S. Department of Homeland Security. Home fires.",
            "https://www.ready.gov/home-fires",
        ),
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — fire and explosion hazards.",
            IFRC_URL,
        ),
    ],
    "earthquake": [
        (
            "U.S. Geological Survey. Earthquake safety.",
            "https://www.usgs.gov/programs/earthquake-hazards/earthquake-safety",
        ),
        (
            "U.S. Department of Homeland Security. Earthquakes.",
            "https://www.ready.gov/earthquakes",
        ),
    ],
    "flood": [
        (
            "National Weather Service. Turn Around Don't Drown®.",
            "https://www.weather.gov/safety/flood-turn-around-dont-drown",
        ),
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — flood hazards.",
            IFRC_URL,
        ),
    ],
    "communication_plan": [
        (
            "American Red Cross. Communication plan.",
            "https://www.redcross.org/get-help/how-to-prepare-for-emergencies/"
            "make-a-plan/communication-plan",
        ),
        (
            "U.S. Department of Homeland Security. Make a plan.",
            "https://www.ready.gov/plan",
        ),
    ],
    "trip_planning": [
        (
            "U.S. Department of Homeland Security. Build a kit.",
            "https://www.ready.gov/kit",
        ),
        (
            "IFRC (2025). International First Aid, Resuscitation and Education "
            "Guidelines 2025 — preparedness.",
            IFRC_URL,
        ),
    ],
    "morse_code": [
        (
            "ITU-R Recommendation M.1677-1 (2009). International Morse code.",
            "https://www.itu.int/rec/R-REC-M.1677-1-200910-I/",
        ),
    ],
}

# Native-language public sources for CPR / AED (not translations of each other).
LOCALE_CPR_AED_SOURCES = {
    "en": {
        "karpa_cpr": [
            (
                "IFRC (2025). International First Aid, Resuscitation and "
                "Education Guidelines 2025 — unresponsive and abnormal breathing "
                "(adolescent and adult).",
                IFRC_URL,
            ),
            (
                "American Red Cross. CPR techniques and sequence.",
                "https://guidelines.redcross.org/guidelines-database/"
                "cpr-techniques-and-sequence/",
            ),
        ],
        "karpa_aed": [
            (
                "IFRC (2025). International First Aid, Resuscitation and "
                "Education Guidelines 2025 — AED during CPR.",
                IFRC_URL,
            ),
            (
                "American Red Cross. CPR techniques and sequence.",
                "https://guidelines.redcross.org/guidelines-database/"
                "cpr-techniques-and-sequence/",
            ),
        ],
    },
    "de": {
        "karpa_cpr": [
            (
                "Deutsches Rotes Kreuz. Erste-Hilfe: Prüfen, Rufen, Drücken.",
                "https://www.drk.de/hilfe-in-deutschland/erste-hilfe/"
                "erste-hilfe-massnahmen-zur-wiederbelebung-pruefen-rufen-druecken/",
            ),
            (
                "Deutsches Rotes Kreuz. Herz-Lungen-Wiederbelebung.",
                "https://www.drk.de/hilfe-in-deutschland/erste-hilfe/"
                "herz-lungen-wiederbelebung/",
            ),
        ],
        "karpa_aed": [
            (
                "Deutsches Rotes Kreuz. Herz-Lungen-Wiederbelebung (AED).",
                "https://www.drk.de/hilfe-in-deutschland/erste-hilfe/"
                "herz-lungen-wiederbelebung/",
            ),
        ],
    },
    "es": {
        "karpa_cpr": [
            (
                "European Resuscitation Council (2025). Guía de Soporte Vital "
                "Básico para adultos (traducción oficial al castellano).",
                "http://www.iavante.es/sites/default/files/"
                "10%20ERC%20Guidelines%20%20BLS%202025%20ESP.pdf",
            ),
        ],
        "karpa_aed": [
            (
                "European Resuscitation Council (2025). Guía de Soporte Vital "
                "Básico para adultos — DEA.",
                "http://www.iavante.es/sites/default/files/"
                "10%20ERC%20Guidelines%20%20BLS%202025%20ESP.pdf",
            ),
        ],
    },
    "fr": {
        "karpa_cpr": [
            (
                "Croix-Rouge française. L'arrêt cardiaque.",
                "https://www.croix-rouge.fr/les-gestes-de-premiers-secours/"
                "arret-cardiaque",
            ),
        ],
        "karpa_aed": [
            (
                "Croix-Rouge française. Comment utiliser un défibrillateur ?",
                "https://www.croix-rouge.fr/les-gestes-de-premiers-secours/"
                "defibrillateur",
            ),
        ],
    },
    "el": {
        "karpa_cpr": [
            (
                "ΣΚΑΪ — Οδηγίες Ελληνικού Ερυθρού Σταυρού για καρδιακή ανακοπή.",
                "https://www.skai.gr/news/health/kardiaki-anakopi-oi-protes-"
                "voitheies-symfona-me-ton-elliniko-erythro-stayro",
            ),
        ],
        "karpa_aed": [
            (
                "Newsbeast — Οδηγός ΚΑΡΠΑ και απινιδωτή (βήμα-βήμα).",
                "https://www.newsbeast.gr/health/arthro/12606984/"
                "pos-na-kanete-karpa-kai-chrisi-apinidoti-vinteo-kai-odigos-vima-vima",
            ),
        ],
    },
    "ar": {
        "karpa_cpr": [
            (
                "الصليب الأحمر الأسترالي. دليل أساسيات الإسعافات الأولية "
                "(العربية) — سلسلة DRSABCD.",
                "https://www.redcross.org.au/globalassets/cms/first-aid/"
                "first-aid-pdfs/first-aid-essentials/"
                "red-cross-essential-first-aid-guide-arabic.pdf",
            ),
        ],
        "karpa_aed": [
            (
                "الصليب الأحمر الأسترالي. دليل أساسيات الإسعافات الأولية "
                "(العربية) — جهاز الصدمات الكهربائية.",
                "https://www.redcross.org.au/globalassets/cms/first-aid/"
                "first-aid-pdfs/first-aid-essentials/"
                "red-cross-essential-first-aid-guide-arabic.pdf",
            ),
        ],
    },
    "zh": {
        "karpa_cpr": [
            (
                "中国红十字会. “救命神器”AED该如何使用呢？（含心肺复苏要点）",
                "https://www.redcross.org.cn/html/2025-07/108777.html",
            ),
        ],
        "karpa_aed": [
            (
                "中国红十字会. “救命神器”AED该如何使用呢？",
                "https://www.redcross.org.cn/html/2025-07/108777.html",
            ),
        ],
    },
}

RELATED_HEADER = {
    "en": "## Related",
    "de": "## Verwandt",
    "es": "## Relacionado",
    "fr": "## Voir aussi",
    "el": "## Σχετικά",
    "ar": "## ذات صلة",
    "zh": "## 相关",
}

CPR_SUMMARY = {
    "en": "Unresponsive, abnormal breathing: call help and start compressions.",
    "de": "Keine Reaktion, abnormale Atmung: Hilfe rufen und komprimieren.",
    "es": "Sin respuesta, respiración anormal: pedir ayuda y comprimir.",
    "fr": "Inconscient, respiration anormale : alerter et comprimer.",
    "el": "Δεν ανταποκρίνεται, ανώμαλη αναπνοή: κλήση βοήθειας και συμπιέσεις.",
    "ar": "لا استجابة وتنفس غير طبيعي: اتصل واضغط على الصدر.",
    "zh": "无反应、呼吸异常：呼救并开始按压。",
}

AED_META = {
    "en": (
        "AED — essentials",
        "During CPR: fetch device, follow prompts, minimize pauses.",
    ),
    "de": (
        "AED — Grundlagen",
        "Während CPR: Gerät holen, Anweisungen folgen, Pausen minimieren.",
    ),
    "es": (
        "DESA — esenciales",
        "Durante RCP: traer el equipo, seguir instrucciones, minimizar pausas.",
    ),
    "fr": (
        "DAE — essentiels",
        "Pendant la RCP : apporter l’appareil, suivre la voix, limiter les pauses.",
    ),
    "el": (
        "AED — βασικά",
        "Με ΚΑΡΠΑ: φέρτε απινιδωτή, ακολουθήστε οδηγίες, λίγες παύσεις.",
    ),
    "ar": (
        "AED — أساسيات",
        "أثناء الإنعاش: جلب الجهاز، اتبع الصوت، قلل الانقطاعات.",
    ),
    "zh": (
        "AED — 要点",
        "心肺复苏时：取设备、听语音提示、尽量减少中断。",
    ),
}

CPR_BODIES = {
    "en": """\
> **Disclaimer:** Short offline reminder based on IFRC 2025 first aid guidance. **Not** a substitute for certified training or emergency medical services. **Adults and adolescents only** — use child/infant protocols from qualified training.

## Recognize cardiac arrest
- Person **does not respond** when you speak loudly and gently shake their shoulders.
- **Open the airway** (head tilt, chin lift) and check for **normal breathing** for up to **10 seconds** (look, listen, feel).
- **Gasping, irregular, or absent breathing is not normal** — start CPR.

## Get help
- **Shout for help**; ask someone to call emergency services and fetch an **AED** if one is nearby.
- If you are alone with a phone, use **speaker or hands-free**, call emergency services, and start CPR (the dispatcher can guide you).
- **If you are unsure**, start CPR — you are unlikely to harm someone who needs it.

## Chest compressions (adults and adolescents)
![CPR Compressions](assets/images/cpr_compressions.svg)
- **Centre of the chest**, **lower half of the sternum**.
- **Push hard and fast:** **100–120 compressions per minute**.
- **Depth about 5 cm** (2 in); **do not exceed 6 cm** (2.4 in).
- **Allow full chest recoil** between compressions; do not lean on the chest.
- **Rotate who compresses every 2 minutes** when another rescuer is available.
- **Minimize pauses** between compressions.

## Rescue breaths (if trained, able, and willing)
- **30 compressions : 2 rescue breaths** for adults and adolescents.
- Each breath about **1 second**, enough for **chest rise**; pauses for breaths should be **under 10 seconds**.
- If untrained, unable, or unwilling: **compression-only CPR** until professional help arrives.

## Continue until
- Emergency responders take over, you must stop for safety, or you are too exhausted to continue (switch roles if possible).

## Related
- If an **AED** is available, keep compressions going while it is fetched and set up — see [AED — essentials](wiki:karpa_aed).""",
    "de": """\
> **Hinweis:** Kurze Offline-Erinnerung nach dem **Deutschen Roten Kreuz** (Prüfen, Rufen, Drücken / Herz-Lungen-Wiederbelebung). **Kein** Ersatz für Rotkreuzkurs oder Notarzt. **Erwachsene und Jugendliche** — für Säuglinge und Kinder gelten besondere HLW-Maßnahmen.

## Prüfen
- **Keine Reaktion** auf Ansprache und vorsichtiges Rütteln an den Schultern: Bewusstlosigkeit.
- Kopf nach **hinten beugen**, Mund öffnen: **keine normale Atmung** oder Zweifel daran → Kreislaufstillstand.

## Rufen
- Weitere Personen hinzuziehen; **Notruf 112** (notärztlicher Dienst).
- Allein: selbst **112** anrufen.

## Drücken
![CPR Compressions](assets/images/cpr_compressions.svg)
- Neben der Person knien, Oberkörper frei machen.
- Ballen einer Hand auf die **Mitte des Brustkorbs** (unteres Drittel des Brustbeins), andere Hand darauf, Arme gestreckt.
- Senkrecht drücken: **100 bis 120 Mal pro Minute**, **circa 5 bis 6 cm** tief; Brustkorb vollständig entlasten (Druck- und Entlastungsdauer gleich).
- **30 × Herzdruckmassage, 2 × Atemspende** im Wechsel, wenn Atemspende möglich; sonst nur Kompressionen.
- Helfer nach **ca. zwei Minuten** wechseln; fortsetzen bis Rettungsdienst übernimmt oder normale Atmung einsetzt.

## Verwandt
- **AED** holen und **Sprachanweisungen** folgen — [AED — Grundlagen](wiki:karpa_aed).""",
    "es": """\
> **Aviso:** Recordatorio offline según **Guías ERC 2025 de Soporte Vital Básico para adultos** (traducción oficial al castellano). **No** sustituye formación certificada ni el 112. **Solo adultos y adolescentes** — niños y lactantes: guías ERC pediátricas/neonatales.

## Tres pasos para salvar una vida
1. **Compruebe:** ¿es seguro acercarse? ¿La persona está consciente?
2. **Llame** al número de emergencias local **sin demora** si no responde; evalúe la respiración.
3. **RCP:** si no responde y tiene **respiración anormal**, comience de inmediato. Conécte un **DEA** en cuanto esté disponible.

## Reconocer parada cardíaca
- Sospeche parada cardíaca en cualquier persona que **no responda**.
- **Respiración agónica, jadeo o lenta y laboriosa** = anormal — asuma parada cardíaca e inicie RCP.
- **Si hay duda**, asuma parada cardíaca y comience RCP.

## Compresiones torácicas
![CPR Compressions](assets/images/cpr_compressions.svg)
- Talón de la mano en la **mitad inferior del esternón** (centro del pecho); entrelace dedos; hombros sobre el pecho; brazos rectos.
- Profundidad **al menos 5 cm, no más de 6 cm**; velocidad **100–120 min⁻¹**; reexpansión completa; evite apoyarse en el pecho.
- Si está formado: **30 compresiones : 2 ventilaciones** (solo el aire necesario para que el pecho se eleve).
- Si no está capacitado: **compresiones continuas** sin interrupciones.

## Relacionado
- **DEA** tan pronto como esté disponible — [DESA — esenciales](wiki:karpa_aed).""",
    "fr": """\
> **Avertissement :** Rappel hors ligne d’après le **guide des gestes qui sauvent de la Croix-Rouge française** (formation PSC 1). **Ne remplace pas** une formation ni les secours (**15** ou **18**). **Adultes et adolescents** sur plan dur.

## Observer la victime
- Vérifiez qu’elle **ne réagit pas** et **ne respire pas normalement**.

## Appeler les secours
- Demandez d’alerter les **secours d’urgence (15 ou 18)** et d’apporter un **défibrillateur automatisé externe (DAE)** s’il est disponible.
- Faites tout cela vous-même si vous êtes seul.

## Massage cardiaque
![CPR Compressions](assets/images/cpr_compressions.svg)
- Victime sur un **plan dur** ; agenouillé à côté ; **poitrine nue**.
- Talon d’une main au **milieu de la poitrine** ; autre main par-dessus ; bras tendus ; comprimez le sternum **de 5 à 6 cm**, **environ 100 par minute** (2 compressions par seconde).
- Après chaque pression, laissez la poitrine **reprendre sa position** ; durée compression = durée relâchement.
- **30 compressions thoraciques**, puis **2 insufflations** (bouche-à-bouche, environ **1 seconde** chacune, poitrine qui se soulève).
- Poursuivez jusqu’à l’arrivée des secours ou reprise d’une **respiration normale**.

## Voir aussi
- Poursuivez le massage jusqu’à l’arrivée du **DAE** — [DAE — essentiels](wiki:karpa_aed).""",
    "el": """\
> **Αποποίηση:** Σύντομη υπενθύμιση από **οδηγίες Ελληνικού Ερυθρού Σταυρού** (μέσω δημοσίων ανακοινώσεων). **Δεν** αντικαθιστά πιστοποιημένη εκπαίδευση ούτε **166** / **112**. **Ενήλικες και έφηβοι** — για παιδιά/βρέφη ισχύουν διαφοροποιήσεις.

## Πότε ξεκινάτε ΚΑΡΠΑ
- Το θύμα **δεν αντιδρά** και **δεν αναπνέει κανονικά** (λιγότερες από **2 αναπνευστικές κινήσεις σε 10 δευτερόλεπτα**).
- Ελέγξτε αν αντιδρά: χτυπήστε ελαφρά τους ώμους και ρωτήστε «είσαι καλά;».
- Ελέγξτε αναπνοή: αυτί κοντά στο στόμα, ταυτόχρονα κοιτάξτε τον θώρακα.

## Βοήθεια
- Καλέστε **άμεσα** **166** και **112**.
- Ζητήστε από άλλον να φέρει **AED** αν υπάρχει κοντά.

## ΚΑΡΠΑ
![CPR Compressions](assets/images/cpr_compressions.svg)
- Χέρια το ένα πάνω στο άλλο στο **κέντρο του θώρακα**· **30 θωρακικές συμπιέσεις** (περίπου **2 ανά δευτερόλεπτο**).
- Έπειτα **2 αναπνοές διάσωσης** (στόμα με στόμα).
- Εναλλαγή **30 : 2** μέχρι σημεία ζωής ή άφιξη ασθενοφόρου.

## Σχετικά
- **AED** — [AED — βασικά](wiki:karpa_aed).""",
    "ar": """\
> **تنبيه:** تذكير دون اتصال من **دليل الصليب الأحمر الأسترالي لأساسيات الإسعافات الأولية (العربية)**. **ليس** بديلاً للتدريب أو الطوارئ. **للبالغين والمراهقين** — الأطفال والرضع يحتاجون عناية خاصة.

## الإنعاش القلبي الرئوي للبالغين
1. تأكد من **سلامة المشهد** والمنطقة المحيطة.
2. اضغط على الشخص وتحدث بصوت عالٍ: «**هل أنت بخير؟**»
3. **اصرخ** طلبًا للمساعدة؛ اتصل **911** (أو رقم الطوارئ المحلي)؛ اطلب **مزيل الرجفان (AED)**.
4. تحقق من **التنفس**.
5. إذا **لا يستجيب** أو **يتنفس بصعوبة/يلهث فقط**، ابدأ الإنعاش.
6. **30 ضغطة** بمعدل **100–120** نبضة/دقيقة وعمق **5–6 سم** (2–2.4 بوصة)؛ دع الصدر يرتفع قبل الضغطة التالية.
7. افتح مجرى الهواء وأعطِ **نفسين** (أو إنعاش **يدوي فقط** إن لم تكن مدرّبًا).

## استمر حتى
- وصول المساعدة المتقدمة، أو استجابة الشخص، أو خطر على المشهد.

## ذات صلة
- **AED** — [AED — أساسيات](wiki:karpa_aed).""",
    "zh": """\
> **声明：** 根据**中国红十字会**公开发布的急救科普（含心肺复苏与AED）。**不能**替代持证培训或120急救。**成人和青少年** — 儿童/婴儿需专门手法。

## 黄金四分钟
- 发现有人突然昏厥、无反应时，在**黄金四分钟**内实施有效心肺复苏并正确使用 **AED**，对挽救生命至关重要。

## 心肺复苏要点
![CPR Compressions](assets/images/cpr_compressions.svg)
- 按 **30 : 2** 的比例实施**胸外按压和人工呼吸**（约每 **2 分钟** 5 组后，AED 可再次分析心律）。
- 按压应**用力、快速**，胸廓充分回弹。

## 相关
- **AED** 使用步骤见 [AED — 要点](wiki:karpa_aed)。""",
}

AED_BODIES = {
    "en": """\
> **Disclaimer:** Short offline reminder based on IFRC 2025 first aid guidance. **Not** a substitute for certified training. Use with ongoing **CPR** on adults/adolescents in cardiac arrest.

## When to use
- During **CPR** when an automated external defibrillator (**AED**) is available nearby.
- **Keep chest compressions going** while the AED is fetched and prepared.

## Steps
![AED Placement](assets/images/cpr_aed.png)
- Turn on the AED and **follow voice prompts**.
- **Bare chest**; attach pads exactly as shown on the device diagram.
- **Do not touch** the person during rhythm **analysis** or **shock**.
- **Resume compressions immediately** after a shock and between cycles as prompted.
- **Minimize pauses** in compressions before and after shock delivery.

## Related
- Chest compressions and rescue breaths: [CPR — essentials](wiki:karpa_cpr).""",
    "de": """\
> **Hinweis:** Nach **DRK** Herz-Lungen-Wiederbelebung. Mit laufender CPR anwenden.

## Wann
- **AED-Gerät** in der Nähe: holen oder holen lassen; anschließen und **Sprachanweisungen** folgen.
- Mit mehreren Helfenden: CPR bis AED einsatzbereit; **eine einzelne Person soll die Wiederbelebung nicht unterbrechen**, um einen AED zu holen.

## Schritte
![AED Placement](assets/images/cpr_aed.png)
- Gerät anschließen, Anweisungen befolgen.
- **Nicht berühren** während Analyse oder Schock.
- Danach **30:2** (Drücken/Beatmen) fortsetzen.

## Verwandt
- [CPR — Grundlagen](wiki:karpa_cpr).""",
    "es": """\
> **Aviso:** Según **Guías ERC 2025** (SVB adultos). Usar con **RCP** en curso.

## Cuándo y cómo (DEA)
- Use un **DEA tan pronto como esté disponible**; enciéndalo y **siga indicaciones audio/visuales**.
- **Pecho desnudo**; parches según el DEA; si hay más de un resucitador, **continúe RCP** mientras se colocan parches.
- **Nadie toque** al paciente durante análisis o descarga.
- Tras descarga (o si no se indica): **reinicie compresiones de inmediato** y siga instrucciones del DEA.

## Relacionado
- [RCP — esenciales](wiki:karpa_cpr).""",
    "fr": """\
> **Avertissement :** D’après la **Croix-Rouge française** (gestes qui sauvent). Pendant la **RCP**.

## Étapes (DAE)
1. **Poursuivre le massage cardiaque** jusqu’à l’arrivée du DAE.
2. Mettre le DAE en marche et **suivre les instructions** de l’appareil.
3. **Poitrine nue** ; électrodes à même la peau selon l’emballage ou l’appareil.
4. **Personne ne touche** la victime pendant l’**analyse** du rythme.
5. Si choc indiqué : tous **éloignés** ; appuyer sur le bouton si demandé (DAE semi-automatique).
6. Si le DAE l’invite : **30 compressions et 2 insufflations** ; continuer jusqu’aux secours ou respiration normale.
7. **Ne pas éteindre** le DAE ; laisser les électrodes en place.

## Voir aussi
- [RCP — essentiels](wiki:karpa_cpr).""",
    "el": """\
> **Αποποίηση:** Σύντομη υπενθύμιση από δημοσιευμένο **οδηγό ΚΑΡΠΑ και απινιδωτή** (βήμα-βήμα). Με ενεργή **ΚΑΡΠΑ**.

## Βήματα AED
![AED Placement](assets/images/cpr_aed.png)
- Ενεργοποιήστε το **AED** και ακολουθήστε τις **φωνητικές οδηγίες**.
- **Γυμνό στήθος**· τοποθετήστε τα ηλεκτρόδια όπως δείχνει η συσκευή.
- **Μην αγγίζετε** κατά **ανάλυση** ή **απινίδωση**.
- Μετά την απινίδωση: **αμέσως συνεχίστε ΚΑΡΠΑ** (30:2) σύμφωνα με τις οδηγίες.

## Σχετικά
- [ΚΑΡΠΑ — βασικά](wiki:karpa_cpr).""",
    "ar": """\
> **تنبيه:** من **دليل الصليب الأحمر الأسترالي (العربية)**. مع **الإنعاش القلبي الرئوي** الجاري.

## الخطوات
![AED Placement](assets/images/cpr_aed.png)
- استمر في **الضغط والتنفس** حتى وصول **مزيل الرجفان (AED)** وتقديم الرعاية المتقدمة.
- شغّل الجهاز واتبع التعليمات؛ **صدر عاري**؛ لصق اللاصقات كما على الجهاز.
- **لا تلمس** أثناء التحليل أو الصدمة.
- **استأنف الإنعاش** فورًا بعد الصدمة.

## ذات صلة
- [أساسيات الإنعاش](wiki:karpa_cpr).""",
    "zh": """\
> **声明：** 据**中国红十字会**公开发布内容。与**心肺复苏**同时进行。

## AED使用步骤
![AED Placement](assets/images/cpr_aed.png)
1. **打开AED电源**，按语音提示操作。
2. **贴电极片**：右上方胸骨右缘锁骨下；左乳头外侧（左腋前线后第五肋间）；紧贴裸露胸部。
3. **分析心律**：示意周围人勿接触患者，等待AED分析。
4. 若提示需电击：充电后确保无人接触，按**电击**按钮。
5. 除颤后**立即**按 **30:2** 做胸外按压和人工呼吸；约2分钟后AED可再次分析，遵循语音直至专业人员到达。
6. 若提示**不需电除颤**，继续心肺复苏。

## 相关
- [心肺复苏 — 要点](wiki:karpa_cpr)。""",
}


def format_sources(locale: str, article_id: str) -> str:
    header = SOURCES_HEADER[locale]
    lines = [header]
    if article_id in ("karpa_cpr", "karpa_aed"):
        entries = LOCALE_CPR_AED_SOURCES[locale][article_id]
    else:
        entries = ARTICLE_SOURCES[article_id]
    for title, url in entries:
        lines.append(f"- [{title}]({url})")
    return "\n".join(lines)


def strip_existing_sources(body: str) -> str:
    for header in SOURCES_HEADER.values():
        idx = body.find(f"\n{header}")
        if idx != -1:
            return body[:idx].rstrip()
    return body.rstrip()


def _escape_yaml(value: str) -> str:
    if "\n" in value or ":" in value or value.startswith(("#", "-", "[")):
        return json.dumps(value, ensure_ascii=False)
    return value


def _parse_md(raw: str) -> tuple[str, str, str]:
    if not raw.startswith("---"):
        return "", "", raw.strip()
    end = raw.index("---", 3)
    if end < 0:
        return "", "", raw.strip()
    front = raw[3:end].strip()
    body = raw[end + 3 :].lstrip("\n")
    title = ""
    summary = ""
    for line in front.splitlines():
        if line.startswith("title:"):
            title = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("summary:"):
            summary = line.split(":", 1)[1].strip().strip('"')
    return title, summary, body


def _format_md(title: str, summary: str, body: str) -> str:
    return (
        f"---\n"
        f"title: {_escape_yaml(title)}\n"
        f"summary: {_escape_yaml(summary)}\n"
        f"---\n"
        f"{body.rstrip()}\n"
    )


def patch_locale_dir(locale_dir: Path, locale: str) -> None:
    for path in sorted(locale_dir.glob("*.md")):
        article_id = path.stem
        title, summary, body = _parse_md(path.read_text(encoding="utf-8"))
        if article_id == "karpa_cpr" and locale in CPR_BODIES:
            body = CPR_BODIES[locale].strip()
            summary = CPR_SUMMARY[locale]
        elif article_id == "karpa_aed" and locale in AED_BODIES:
            body = AED_BODIES[locale].strip()
            title, summary = AED_META[locale]
        else:
            body = strip_existing_sources(body)
        body = body + "\n\n" + format_sources(locale, article_id)
        path.write_text(_format_md(title, summary, body), encoding="utf-8")
        print(f"  {path.name}")


def main() -> None:
    wiki_dir = Path(__file__).resolve().parents[1] / "assets" / "wiki"
    for locale in sorted(SOURCES_HEADER):
        locale_dir = wiki_dir / locale
        if not locale_dir.is_dir():
            continue
        print(f"Patched {locale}/")
        patch_locale_dir(locale_dir, locale)


if __name__ == "__main__":
    main()
