/// عيّنة «مسألة بأجزاء» (parts-v1 — قرار ٦٨) للاختبارات فقط.
///
/// بُنيت على مثال دارة توالٍ من المادة ٢٠ §٢ ليكون السلّم حقيقياً:
///  • الجزء ١ (١٠): العلاقة ٥ · التعويض ٣ · النتيجة ١ · الوحدة ١ — وله أربعة
///    خيارات (وضع القرار ٦١ المؤقَّت) ومفتاحه العددي 100 Ω.
///  • الجزء ٢ (١٠): معامل القدرة cos φ — بلا بُعد ⇒ السلّم بلا سطر وحدة فعلي
///    (`unitRequired: false`)، ومتابعة خطأ موصولة بالجزء ١:
///    المقبول = 60 ÷ (جواب الطالب في الجزء ١)^1.
library;

/// بند مسألة كاملة بأجزاءين — الصيغة كما يولّدها `tools/gen_items.py`.
Map<String, dynamic> partsSampleItem({int id = 91, bool approved = false}) =>
    <String, dynamic>{
      'id': id,
      'templateId': 'T.PARTS.SAMPLE',
      'unit': 'U2',
      'chapter': 'U2C5',
      'type': 'problem',
      'difficulty': 3,
      'weight': 20,
      'approved': approved,
      'stem': 'دارة توالٍ R = 60 Ω وممانعة محصلة X = 80 Ω على مصدر جيبي.',
      'options': <String>[],
      'correctIndex': -1,
      'optionRules': <String>[],
      'optionValues': <num?>[],
      'answer': null,
      'grading': 'parts-v1',
      'solutionSteps': <String>[
        '١) 100 Ω — 10 درجات',
        '٢) 0٫6 — 10 درجات',
      ],
      'followThrough': <Map<String, dynamic>>[
        <String, dynamic>{
          'part': '٢',
          'accept': <Map<String, dynamic>>[
            <String, dynamic>{
              'dependsOn': '١',
              'power': -1.0,
              'scale': 60.0,
              'tolerance': 0.02,
            },
          ],
        },
      ],
      'parts': <Map<String, dynamic>>[
        <String, dynamic>{
          'n': 1,
          'label': '١',
          'prompt': 'استنتج علاقة الممانعة الزولية ثم احسب قيمتها.',
          'weight': 10,
          'options': <String>['140', '60', '20', '100 Ω'],
          'correctIndex': 3,
          'optionRules': <String?>['Z_algebraic', 'mix', 'mix', null],
          'optionValues': <num?>[140.0, 60.0, 20.0, 100.0],
          'solutionSteps': <String>[
            '(A) خطأ [Z_algebraic]: جمع الممانعات جبرياً بدل فيثاغورث',
          ],
          'answer': <String, dynamic>{
            'value': 100.0,
            'unit': 'Ω',
            'text': '100 Ω',
            'tolerance': 0.02,
            'unitRequired': true,
          },
          'rubric': <Map<String, dynamic>>[
            <String, dynamic>{
              'step': 'الجزء ١ · العلاقة: Z = √(R² + X²)',
              'points': 5,
              'kind': 'relation',
              'keys': <String>['√(R² + X²)'],
              'antiKeys': <String>['Z = R + X'],
            },
            <String, dynamic>{
              'step': 'الجزء ١ · التعويض: Z = √(60² + 80²)',
              'points': 3,
              'kind': 'substitution',
              'expect': <String>['60', '80'],
            },
            <String, dynamic>{
              'step': 'الجزء ١ · النتيجة: 100 Ω',
              'points': 1,
              'kind': 'result',
            },
            <String, dynamic>{
              'step': 'الجزء ١ · الوحدة',
              'points': 1,
              'kind': 'unit',
              'keys': <String>['Ω'],
            },
          ],
        },
        <String, dynamic>{
          'n': 2,
          'label': '٢',
          'prompt': 'احسب معامل القدرة cos φ للدارة.',
          'weight': 10,
          'options': <String>[],
          'correctIndex': -1,
          'optionRules': <String?>[],
          'optionValues': <num?>[],
          'solutionSteps': <String>[],
          'answer': <String, dynamic>{
            'value': 0.6,
            'unit': '',
            'text': '0٫6',
            'tolerance': 0.02,
            'unitRequired': false,
          },
          'rubric': <Map<String, dynamic>>[
            <String, dynamic>{
              'step': 'الجزء ٢ · العلاقة: cos φ = R/Z',
              'points': 5,
              'kind': 'relation',
              'keys': <String>['cos φ = R/Z'],
              'antiKeys': <String>['cos φ = Z/R'],
            },
            <String, dynamic>{
              'step': 'الجزء ٢ · التعويض: cos φ = 60/100',
              'points': 3,
              'kind': 'substitution',
              'expect': <String>['60', '100'],
            },
            <String, dynamic>{
              'step': 'الجزء ٢ · النتيجة: 0٫6',
              'points': 1,
              'kind': 'result',
            },
            <String, dynamic>{
              'step': 'الجزء ٢ · الوحدة (مقدار بلا بُعد)',
              'points': 1,
              'kind': 'unit',
            },
          ],
        },
      ],
    };

/// إجابة نموذجية كاملة على الجزء ١ (نصّ السلم حرفياً + الخيار الصحيح).
const String fullRelation1 = 'Z = √(R² + X²)';
const String fullSubst1 = 'Z = √(60² + 80²) = √10000';
const String fullResult1 = '100 Ω';
const int fullChoice1 = 3;

/// إجابة نموذجية كاملة على الجزء ٢.
const String fullRelation2 = 'cos φ = R/Z';
const String fullSubst2 = 'cos φ = 60/100';
const String fullResult2 = '0.6';
