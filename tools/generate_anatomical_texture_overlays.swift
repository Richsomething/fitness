import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasWidth = 1024
private let canvasHeight = 1536

private struct Region {
    let points: [CGPoint]
}

private struct MuscleGroup {
    let order: Int
    let slug: String
    let regions: [Region]
}

private func region(_ values: [(CGFloat, CGFloat)]) -> Region {
    Region(points: values.map(CGPoint.init))
}

private func mirrored(_ source: Region) -> Region {
    Region(points: source.points.map { CGPoint(x: CGFloat(canvasWidth) - $0.x, y: $0.y) })
}

private func paired(_ regions: [Region]) -> [Region] {
    regions + regions.map(mirrored)
}

// All coordinates are in the master image's top-left coordinate system.
// Regions follow the visible muscle bellies rather than broad body-part polygons.
private let femaleGroups: [MuscleGroup] = [
    MuscleGroup(order: 1, slug: "neck-trapezius", regions: [
        region([(458,184),(478,191),(494,209),(504,236),(501,267),(485,285),(469,269),(458,240)]),
        region([(566,184),(546,191),(530,209),(520,236),(523,267),(539,285),(555,269),(566,240)]),
        region([(499,199),(512,191),(525,199),(528,220),(522,250),(512,279),(502,250),(496,220)])
    ]),
    MuscleGroup(order: 2, slug: "shoulders", regions: paired([
        region([(603,266),(630,251),(661,252),(686,268),(701,294),(708,326),(706,356),(697,383),(681,404),(661,414),(646,401),(638,375),(638,345),(641,319),(628,294)])
    ])),
    MuscleGroup(order: 3, slug: "chest", regions: paired([
        region([(514,279),(546,273),(579,275),(610,282),(633,299),(644,326),(646,358),(641,388),(630,412),(610,429),(584,438),(558,435),(536,426),(520,408),(513,383)])
    ])),
    MuscleGroup(order: 4, slug: "biceps", regions: paired([
        region([(645,350),(663,342),(681,349),(695,369),(702,397),(702,426),(696,455),(686,484),(672,511),(655,512),(643,497),(636,472),(634,443),(636,406)])
    ])),
    MuscleGroup(order: 5, slug: "triceps", regions: paired([
        region([(680,346),(698,352),(711,371),(718,399),(720,430),(716,458),(706,486),(695,506),(683,495),(687,474),(693,447),(696,417),(693,386)])
    ])),
    MuscleGroup(order: 6, slug: "forearms", regions: paired([
        region([(684,501),(700,494),(716,503),(729,522),(743,547),(758,572),(773,599),(788,627),(797,653),(796,674),(785,685),(772,681),(758,667),(745,647),(731,625),(716,603),(700,581),(685,558),(674,533),(675,512)]),
        region([(704,508),(717,510),(731,527),(741,552),(746,580),(744,606),(735,627),(724,611),(713,590),(701,567),(692,544),(692,522)]),
        region([(739,548),(754,568),(769,596),(782,625),(790,651),(788,671),(778,678),(767,663),(758,640),(749,613),(741,583)])
    ])),
    MuscleGroup(order: 7, slug: "abs", regions: paired([
        region([(514,424),(540,417),(560,428),(568,449),(565,470),(543,480),(515,476)]),
        region([(514,482),(541,482),(562,492),(569,514),(564,534),(541,540),(514,534)]),
        region([(514,542),(539,542),(560,550),(566,574),(559,594),(538,600),(514,593)]),
        region([(514,601),(538,604),(557,619),(561,646),(553,675),(537,701),(522,716),(514,719)])
    ])),
    MuscleGroup(order: 8, slug: "serratus", regions: paired([
        region([(580,420),(607,414),(629,422),(641,438),(640,455),(624,463),(607,454),(591,442)]),
        region([(591,449),(620,460),(640,470),(642,486),(628,496),(608,485),(590,469)]),
        region([(590,478),(617,493),(635,507),(633,523),(617,530),(598,511),(582,493)])
    ])),
    MuscleGroup(order: 9, slug: "lats", regions: paired([
        region([(629,402),(648,410),(659,431),(661,458),(655,489),(647,521),(638,550),(627,575),(614,598),(602,582),(608,554),(616,522),(620,488),(620,456),(614,428)])
    ])),
    MuscleGroup(order: 10, slug: "obliques", regions: paired([
        region([(579,480),(602,493),(624,516),(638,545),(639,576),(629,607),(613,634),(590,660),(569,675),(557,658),(565,624),(573,587),(577,548),(572,514)])
    ])),
    MuscleGroup(order: 11, slug: "hip-flexors", regions: paired([
        region([(514,648),(542,640),(573,638),(600,647),(620,666),(624,692),(611,716),(588,736),(558,750),(532,739),(514,715)])
    ])),
    MuscleGroup(order: 12, slug: "hips", regions: paired([
        region([(602,640),(627,637),(649,647),(665,668),(673,696),(672,722),(663,748),(649,770),(632,782),(615,773),(606,754),(606,731),(613,705),(621,681)])
    ])),
    MuscleGroup(order: 13, slug: "adductors", regions: paired([
        region([(514,720),(537,718),(558,734),(573,760),(580,797),(579,837),(570,880),(559,923),(545,964),(528,997),(516,1014),(512,984)])
    ])),
    MuscleGroup(order: 14, slug: "quadriceps", regions: paired([
        region([(619,710),(646,716),(663,737),(673,773),(677,819),(674,869),(667,915),(655,957),(638,988),(619,1004),(603,986),(608,950),(615,905),(619,855),(619,804)]),
        region([(577,735),(603,720),(621,738),(630,770),(632,812),(628,858),(621,905),(613,948),(602,985),(585,1004),(570,992),(560,963),(557,923),(557,878),(560,831),(565,781)]),
        region([(546,846),(564,840),(581,854),(591,880),(596,913),(594,947),(585,976),(570,1000),(554,1010),(542,997),(537,974),(537,940),(540,901)])
    ])),
    MuscleGroup(order: 15, slug: "calves", regions: paired([
        region([(559,1006),(585,1002),(608,1009),(625,1029),(637,1060),(641,1097),(638,1137),(629,1173),(617,1204),(607,1233),(599,1265),(588,1300),(571,1310),(557,1298),(548,1271),(543,1236),(540,1198),(540,1157),(543,1114),(548,1074)]),
        region([(588,1010),(608,1013),(624,1032),(633,1062),(636,1098),(631,1138),(619,1172),(606,1196),(598,1165),(596,1124),(596,1081)])
    ])),
    MuscleGroup(order: 16, slug: "shins", regions: paired([
        region([(520,1018),(540,1010),(557,1025),(568,1052),(574,1089),(575,1132),(570,1179),(563,1223),(555,1266),(547,1306),(532,1315),(521,1300),(516,1270),(514,1228),(513,1180),(513,1129),(514,1079)])
    ]))
]

private let maleGroups: [MuscleGroup] = [
    MuscleGroup(order: 1, slug: "neck-trapezius", regions: [
        region([(438,174),(462,181),(486,196),(501,219),(503,246),(493,268),(477,282),(458,270),(445,247),(438,216)]),
        region([(586,174),(562,181),(538,196),(523,219),(521,246),(531,268),(547,282),(566,270),(579,247),(586,216)]),
        region([(499,192),(512,184),(525,192),(528,216),(522,243),(512,264),(502,243),(496,216)])
    ]),
    MuscleGroup(order: 2, slug: "shoulders", regions: paired([
        region([(610,258),(643,245),(678,247),(704,262),(721,286),(728,315),(729,345),(724,372),(712,393),(696,407),(677,409),(659,399),(648,379),(645,354),(647,327),(650,305),(636,282)])
    ])),
    MuscleGroup(order: 3, slug: "chest", regions: paired([
        region([(514,270),(551,262),(587,263),(619,271),(643,287),(655,311),(659,339),(657,367),(649,390),(636,409),(616,422),(592,428),(566,425),(543,416),(525,399),(514,377)])
    ])),
    MuscleGroup(order: 4, slug: "biceps", regions: paired([
        region([(657,346),(680,337),(702,342),(720,357),(733,380),(739,408),(739,437),(734,468),(725,495),(713,519),(699,540),(681,544),(665,531),(654,507),(648,477),(646,445),(649,410),(652,378)])
    ])),
    MuscleGroup(order: 5, slug: "triceps", regions: paired([
        region([(703,338),(722,345),(736,364),(744,391),(747,420),(745,448),(739,475),(730,501),(720,521),(710,533),(701,523),(704,499),(711,471),(716,441),(718,410),(715,379)])
    ])),
    MuscleGroup(order: 6, slug: "forearms", regions: paired([
        region([(707,500),(726,496),(746,506),(762,525),(777,548),(792,573),(808,599),(823,626),(833,651),(835,671),(828,686),(816,692),(803,687),(790,672),(777,651),(764,630),(751,608),(737,585),(721,560),(709,535),(703,514)]),
        region([(731,509),(748,514),(762,531),(773,554),(779,580),(778,604),(769,627),(758,646),(746,628),(734,606),(722,582),(713,556),(714,531)]),
        region([(770,550),(788,572),(804,600),(819,628),(829,653),(830,674),(820,687),(807,681),(797,663),(788,640),(779,614),(771,583)])
    ])),
    MuscleGroup(order: 7, slug: "abs", regions: paired([
        region([(514,420),(542,414),(564,424),(574,445),(571,468),(547,478),(515,474)]),
        region([(514,480),(544,479),(568,489),(575,513),(570,535),(545,542),(514,535)]),
        region([(514,543),(543,543),(566,552),(573,576),(566,598),(543,604),(514,596)]),
        region([(514,604),(541,606),(563,621),(566,648),(559,677),(543,704),(524,724),(514,728)])
    ])),
    MuscleGroup(order: 8, slug: "serratus", regions: paired([
        region([(582,411),(611,406),(636,414),(651,431),(650,449),(634,458),(615,450),(597,438)]),
        region([(594,447),(625,457),(649,469),(653,486),(638,497),(616,487),(596,469)]),
        region([(594,478),(624,491),(648,506),(647,524),(630,533),(608,515),(588,496)])
    ])),
    MuscleGroup(order: 9, slug: "lats", regions: paired([
        region([(642,399),(663,407),(677,428),(681,456),(676,488),(668,521),(657,553),(645,582),(631,605),(616,589),(622,558),(631,525),(636,490),(635,456),(628,425)])
    ])),
    MuscleGroup(order: 10, slug: "obliques", regions: paired([
        region([(580,476),(606,489),(630,511),(647,539),(650,570),(643,601),(627,630),(605,655),(580,677),(561,664),(568,630),(576,593),(582,553),(578,515)])
    ])),
    MuscleGroup(order: 11, slug: "hip-flexors", regions: paired([
        region([(514,645),(545,637),(577,638),(605,648),(625,668),(630,695),(617,721),(593,743),(562,756),(535,744),(514,720)])
    ])),
    MuscleGroup(order: 12, slug: "hips", regions: paired([
        region([(605,640),(630,638),(651,650),(666,672),(672,699),(670,725),(661,750),(648,772),(632,783),(617,774),(609,755),(608,733),(615,707),(623,682)])
    ])),
    MuscleGroup(order: 13, slug: "adductors", regions: paired([
        region([(514,721),(537,719),(558,734),(572,760),(578,795),(576,835),(568,878),(557,923),(544,965),(528,999),(516,1017),(512,987)])
    ])),
    MuscleGroup(order: 14, slug: "quadriceps", regions: paired([
        region([(620,711),(647,718),(665,739),(675,774),(678,819),(675,866),(669,912),(657,954),(640,988),(620,1005),(604,987),(610,949),(616,905),(620,856),(621,806)]),
        region([(578,735),(604,720),(623,739),(632,773),(633,814),(629,858),(622,904),(614,948),(603,985),(586,1005),(571,994),(561,965),(558,924),(559,879),(561,833),(566,783)]),
        region([(546,846),(565,840),(583,854),(593,881),(598,913),(596,948),(587,978),(572,1002),(555,1012),(543,999),(537,976),(538,941),(541,901)])
    ])),
    MuscleGroup(order: 15, slug: "calves", regions: paired([
        region([(558,1006),(584,1002),(607,1009),(625,1028),(638,1058),(643,1094),(641,1134),(632,1171),(620,1203),(610,1233),(601,1265),(590,1301),(572,1312),(558,1300),(549,1273),(543,1238),(540,1199),(540,1158),(543,1115),(548,1074)]),
        region([(589,1010),(610,1014),(626,1033),(635,1063),(638,1097),(633,1137),(621,1172),(607,1198),(599,1167),(597,1125),(597,1082)])
    ])),
    MuscleGroup(order: 16, slug: "shins", regions: paired([
        region([(520,1018),(541,1010),(558,1026),(569,1053),(575,1090),(576,1133),(571,1180),(564,1224),(556,1267),(548,1308),(532,1317),(521,1302),(516,1271),(514,1229),(513,1181),(513,1130),(514,1080)])
    ]))
]

private let femaleBackGroups: [MuscleGroup] = [
    MuscleGroup(order: 1, slug: "neck", regions: paired([
        region([(514,118),(535,111),(555,123),(570,147),(578,176),(573,207),(558,232),(536,251),(515,248)])
    ])),
    MuscleGroup(order: 2, slug: "trapezius", regions: paired([
        region([(514,181),(546,187),(579,200),(609,220),(635,245),(650,274),(650,305),(640,334),(623,364),(603,394),(580,427),(555,459),(531,484),(514,491)])
    ])),
    MuscleGroup(order: 3, slug: "rear-shoulders", regions: paired([
        region([(609,264),(640,250),(671,250),(696,264),(712,287),(718,316),(716,344),(707,367),(691,384),(670,395),(648,390),(631,375),(622,353),(620,325),(624,299)])
    ])),
    MuscleGroup(order: 4, slug: "infraspinatus", regions: paired([
        region([(578,300),(606,289),(635,294),(660,309),(677,330),(682,351),(672,371),(651,387),(625,394),(601,388),(584,371),(574,348)])
    ])),
    MuscleGroup(order: 5, slug: "teres-major", regions: paired([
        region([(596,367),(623,354),(652,357),(675,373),(686,392),(682,413),(666,431),(643,439),(619,433),(602,418),(591,397)])
    ])),
    MuscleGroup(order: 6, slug: "triceps", regions: paired([
        region([(661,365),(685,360),(708,373),(722,397),(729,426),(731,457),(726,487),(715,516),(701,540),(683,543),(668,530),(659,506),(655,478),(656,443),(657,405)])
    ])),
    MuscleGroup(order: 7, slug: "forearms", regions: paired([
        region([(700,515),(719,511),(738,522),(754,542),(770,566),(786,591),(802,617),(817,642),(825,663),(825,680),(816,692),(803,694),(790,682),(778,664),(765,645),(751,623),(737,599),(722,575),(709,548)])
    ])),
    MuscleGroup(order: 8, slug: "lats", regions: paired([
        region([(599,389),(625,397),(648,417),(660,444),(663,476),(657,509),(646,541),(630,570),(611,596),(589,618),(563,637),(536,651),(515,643),(521,610),(529,574),(536,536),(540,496),(547,458),(564,424)])
    ])),
    MuscleGroup(order: 9, slug: "erector-spinae", regions: paired([
        region([(514,381),(536,389),(554,410),(565,441),(570,479),(570,519),(566,558),(559,596),(549,630),(534,661),(520,683),(514,686)])
    ])),
    MuscleGroup(order: 10, slug: "gluteus-medius", regions: paired([
        region([(563,584),(592,575),(622,578),(648,591),(667,612),(675,637),(673,661),(663,682),(647,700),(629,711),(610,710),(595,697),(591,677),(596,654),(587,629)])
    ])),
    MuscleGroup(order: 11, slug: "gluteus-maximus", regions: paired([
        region([(514,597),(544,584),(578,582),(610,591),(636,608),(654,632),(663,660),(664,688),(656,714),(638,737),(613,753),(584,761),(556,757),(534,745),(520,725),(514,698)])
    ])),
    MuscleGroup(order: 12, slug: "hamstrings", regions: paired([
        region([(603,754),(630,753),(653,768),(667,795),(673,829),(673,866),(669,905),(661,943),(650,976),(636,1004),(619,1025),(602,1020),(598,996),(603,964),(608,928),(611,888),(611,846),(607,805)]),
        region([(539,752),(568,750),(593,764),(605,791),(610,825),(609,862),(604,900),(596,938),(585,975),(569,1009),(551,1029),(535,1022),(529,1000),(532,970),(537,935),(541,897),(541,857),(537,814)])
    ])),
    MuscleGroup(order: 13, slug: "adductors", regions: paired([
        region([(514,753),(536,755),(551,775),(558,806),(559,841),(555,877),(548,913),(540,948),(530,982),(520,1016),(512,1001)])
    ])),
    MuscleGroup(order: 14, slug: "calves", regions: paired([
        region([(548,1005),(573,1001),(598,1007),(619,1025),(633,1053),(640,1087),(640,1124),(635,1159),(626,1190),(614,1212),(598,1226),(580,1224),(563,1215),(550,1195),(543,1166),(540,1132),(540,1095),(543,1059)])
    ])),
    MuscleGroup(order: 15, slug: "soleus", regions: paired([
        region([(584,1068),(607,1071),(625,1087),(635,1112),(637,1142),(632,1172),(623,1200),(612,1224),(602,1250),(592,1280),(576,1292),(564,1280),(562,1259),(569,1235),(579,1208),(586,1180),(589,1147),(589,1110)])
    ])),
    MuscleGroup(order: 16, slug: "achilles-tendons", regions: paired([
        region([(558,1205),(577,1208),(589,1232),(593,1266),(592,1301),(587,1337),(580,1371),(570,1399),(557,1400),(549,1381),(550,1352),(554,1318),(557,1282),(558,1244)])
    ]))
]

private let maleBackGroups: [MuscleGroup] = [
    MuscleGroup(order: 1, slug: "neck", regions: paired([
        region([(514,105),(539,99),(562,113),(579,138),(588,168),(583,200),(566,228),(542,250),(515,248)])
    ])),
    MuscleGroup(order: 2, slug: "trapezius", regions: paired([
        region([(514,171),(550,177),(587,191),(620,211),(648,236),(665,265),(666,296),(657,326),(641,357),(621,389),(596,422),(569,455),(540,483),(514,492)])
    ])),
    MuscleGroup(order: 3, slug: "rear-shoulders", regions: paired([
        region([(616,252),(651,239),(687,241),(714,256),(731,280),(737,309),(736,339),(728,366),(714,389),(695,407),(672,416),(650,410),(632,393),(621,369),(618,341),(622,309)])
    ])),
    MuscleGroup(order: 4, slug: "infraspinatus", regions: paired([
        region([(585,289),(616,278),(649,283),(678,298),(697,320),(703,343),(694,364),(673,382),(647,392),(620,389),(600,374),(586,352)])
    ])),
    MuscleGroup(order: 5, slug: "teres-major", regions: paired([
        region([(604,356),(634,343),(665,347),(690,364),(701,385),(696,408),(679,428),(654,438),(628,433),(610,417),(599,393)])
    ])),
    MuscleGroup(order: 6, slug: "triceps", regions: paired([
        region([(678,356),(704,350),(728,364),(744,389),(752,420),(754,452),(749,484),(738,515),(723,541),(704,546),(687,533),(677,508),(672,478),(673,442),(674,401)])
    ])),
    MuscleGroup(order: 7, slug: "forearms", regions: paired([
        region([(720,512),(741,508),(762,520),(780,541),(797,566),(814,592),(830,619),(845,645),(853,666),(853,683),(844,696),(830,698),(816,686),(803,668),(789,647),(774,625),(760,601),(744,576),(731,548)])
    ])),
    MuscleGroup(order: 8, slug: "lats", regions: paired([
        region([(607,380),(637,389),(662,410),(677,438),(681,471),(675,507),(664,541),(648,572),(628,600),(604,624),(577,643),(548,657),(517,648),(524,613),(532,575),(539,535),(543,493),(551,452),(570,416)])
    ])),
    MuscleGroup(order: 9, slug: "erector-spinae", regions: paired([
        region([(514,370),(539,378),(559,400),(571,432),(576,471),(576,513),(572,554),(565,594),(554,631),(538,664),(521,688),(514,691)])
    ])),
    MuscleGroup(order: 10, slug: "gluteus-medius", regions: paired([
        region([(568,582),(599,572),(631,575),(659,588),(679,610),(687,636),(685,662),(675,685),(658,703),(638,715),(618,713),(601,699),(597,678),(602,654),(593,628)])
    ])),
    MuscleGroup(order: 11, slug: "gluteus-maximus", regions: paired([
        region([(514,596),(547,582),(584,580),(619,590),(647,608),(666,633),(676,662),(676,692),(667,720),(648,744),(621,761),(590,769),(560,764),(536,751),(521,730),(514,701)])
    ])),
    MuscleGroup(order: 12, slug: "hamstrings", regions: paired([
        region([(610,758),(639,757),(664,773),(679,801),(685,837),(684,875),(679,914),(670,952),(658,986),(643,1014),(624,1035),(606,1030),(602,1005),(607,973),(613,936),(616,896),(616,853),(612,811)]),
        region([(541,756),(571,753),(598,768),(611,795),(616,830),(615,868),(610,907),(602,946),(590,984),(574,1019),(554,1039),(537,1032),(531,1009),(534,978),(539,943),(543,904),(544,863),(540,820)])
    ])),
    MuscleGroup(order: 13, slug: "adductors", regions: paired([
        region([(514,757),(538,759),(554,780),(562,812),(563,848),(559,884),(552,921),(544,957),(533,992),(522,1027),(512,1011)])
    ])),
    MuscleGroup(order: 14, slug: "calves", regions: paired([
        region([(550,1012),(577,1008),(603,1014),(625,1033),(640,1062),(647,1097),(647,1135),(642,1171),(633,1203),(621,1226),(604,1240),(585,1238),(567,1229),(553,1208),(546,1179),(543,1144),(543,1106),(546,1069)])
    ])),
    MuscleGroup(order: 15, slug: "soleus", regions: paired([
        region([(589,1077),(613,1080),(632,1096),(642,1122),(644,1153),(639,1184),(630,1212),(619,1237),(609,1263),(599,1293),(582,1305),(570,1293),(568,1271),(575,1247),(585,1220),(592,1191),(595,1158),(595,1120)])
    ])),
    MuscleGroup(order: 16, slug: "achilles-tendons", regions: paired([
        region([(563,1217),(583,1220),(595,1244),(599,1278),(598,1313),(593,1349),(586,1382),(576,1410),(562,1411),(554,1392),(555,1363),(559,1329),(562,1293),(563,1255)])
    ]))
]

private let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)

private func makeContext(width: Int = canvasWidth, height: Int = canvasHeight) -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo.rawValue
    ) else { fatalError("Cannot create bitmap context") }
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    return context
}

private func smoothClosedPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard points.count > 2 else { return path }
    func point(_ index: Int) -> CGPoint { points[(index + points.count) % points.count] }
    path.move(to: points[0])
    for index in 0..<points.count {
        let p0 = point(index - 1)
        let p1 = point(index)
        let p2 = point(index + 1)
        let p3 = point(index + 2)
        path.addCurve(
            to: p2,
            control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
            control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        )
    }
    path.closeSubpath()
    return path
}

private func makeMask(for group: MuscleGroup) -> CGImage {
    let context = makeContext()
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    for item in group.regions {
        let points = item.points.map { CGPoint(x: $0.x, y: CGFloat(canvasHeight) - $0.y) }
        context.addPath(smoothClosedPath(points))
        context.fillPath()
    }
    guard let image = context.makeImage() else { fatalError("Cannot create mask") }
    return image
}

private func renderedRGBA(_ image: CGImage) -> (context: CGContext, bytes: UnsafeMutablePointer<UInt8>) {
    let context = makeContext()
    context.draw(image, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    guard let data = context.data else { fatalError("Cannot access bitmap data") }
    return (context, data.bindMemory(to: UInt8.self, capacity: canvasWidth * canvasHeight * 4))
}

private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

private func makeTextureOverlay(source: CGImage, mask: CGImage) -> CGImage {
    let sourceBitmap = renderedRGBA(source)
    let maskBitmap = renderedRGBA(mask)
    let output = makeContext()
    guard let outputData = output.data else { fatalError("Cannot access output bitmap") }
    let out = outputData.bindMemory(to: UInt8.self, capacity: canvasWidth * canvasHeight * 4)

    for pixel in 0..<(canvasWidth * canvasHeight) {
        let offset = pixel * 4
        let maskAlpha = Double(maskBitmap.bytes[offset + 3]) / 255
        if maskAlpha <= 0 {
            out[offset] = 0; out[offset + 1] = 0; out[offset + 2] = 0; out[offset + 3] = 0
            continue
        }

        let sourceR = Double(sourceBitmap.bytes[offset]) / 255
        let sourceG = Double(sourceBitmap.bytes[offset + 1]) / 255
        let sourceB = Double(sourceBitmap.bytes[offset + 2]) / 255
        let brightness = max(sourceR, max(sourceG, sourceB))
        let bodyGate = clamp((brightness - 0.055) / 0.20)
        let alpha = maskAlpha * bodyGate
        if alpha <= 0.005 {
            out[offset] = 0; out[offset + 1] = 0; out[offset + 2] = 0; out[offset + 3] = 0
            continue
        }

        let tone = pow(clamp((brightness - 0.08) / 0.92), 0.82)
        let fiberHighlight = pow(clamp((tone - 0.68) / 0.32), 1.35)
        let red = clamp(0.34 + 0.64 * tone)
        let green = clamp(0.035 + 0.39 * pow(tone, 1.30) + 0.30 * fiberHighlight)
        let blue = clamp(0.055 + 0.31 * pow(tone, 1.25) + 0.24 * fiberHighlight)

        out[offset] = UInt8(red * alpha * 255)
        out[offset + 1] = UInt8(green * alpha * 255)
        out[offset + 2] = UInt8(blue * alpha * 255)
        out[offset + 3] = UInt8(alpha * 255)
    }

    guard let image = output.makeImage() else { fatalError("Cannot create overlay") }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("Cannot create PNG destination") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write PNG") }
}

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
    fputs("Usage: swift generate_anatomical_texture_overlays.swift <source.png> <output-directory> [female|male]\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let profile = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : "female"
private let groups: [MuscleGroup]
switch profile {
case "male": groups = maleGroups
case "female-back": groups = femaleBackGroups
case "male-back": groups = maleBackGroups
default: groups = femaleGroups
}
let overlaysURL = outputURL.appendingPathComponent("overlays", isDirectory: true)
let previewsURL = outputURL.appendingPathComponent("previews", isDirectory: true)
try FileManager.default.createDirectory(at: overlaysURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: previewsURL, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let source = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
      source.width == canvasWidth,
      source.height == canvasHeight else {
    fatalError("The source image must be 1024 x 1536 px")
}

var allOverlays: [CGImage] = []
for group in groups {
    let mask = makeMask(for: group)
    let overlay = makeTextureOverlay(source: source, mask: mask)
    let name = String(format: "%02d_%@.png", group.order, group.slug)
    try writePNG(overlay, to: overlaysURL.appendingPathComponent(name))

    let previewContext = makeContext()
    previewContext.draw(source, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    previewContext.draw(overlay, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    if let preview = previewContext.makeImage() {
        try writePNG(preview, to: previewsURL.appendingPathComponent(name))
    }
    allOverlays.append(overlay)
}

let combinedContext = makeContext()
for overlay in allOverlays {
    combinedContext.draw(overlay, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
}
if let combined = combinedContext.makeImage() {
    try writePNG(combined, to: outputURL.appendingPathComponent("all-muscles-overlay.png"))
    let previewContext = makeContext()
    previewContext.draw(source, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    previewContext.draw(combined, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    if let preview = previewContext.makeImage() {
        try writePNG(preview, to: outputURL.appendingPathComponent("all-muscles-preview.png"))
    }
}

try FileManager.default.copyItem(at: sourceURL, to: outputURL.appendingPathComponent("base-reference.png"))
print("Created \(groups.count) anatomical texture overlays in \(outputURL.path)")
