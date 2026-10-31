import Foundation

struct FilmLook: Identifiable, Hashable {
    let id: String
    let title: String
    let family: String
    let saturation: Float
    let contrast: Float
    let brightness: Float
    let warmth: Float
    let fade: Float
    let grain: Float
    let monochrome: Bool

    static let all: [FilmLook] = [
        .init(id:"portra400", title:"Portra 400", family:"Color Negative", saturation:0.88, contrast:0.94, brightness:0.015, warmth:0.045, fade:0.035, grain:0.12, monochrome:false),
        .init(id:"portra800", title:"Portra 800", family:"Color Negative", saturation:0.84, contrast:0.98, brightness:0.005, warmth:0.055, fade:0.02, grain:0.20, monochrome:false),
        .init(id:"ektar100", title:"Ektar 100", family:"Color Negative", saturation:1.22, contrast:1.12, brightness:0, warmth:0.015, fade:0, grain:0.035, monochrome:false),
        .init(id:"gold200", title:"Gold 200", family:"Color Negative", saturation:1.08, contrast:1.04, brightness:0.015, warmth:0.075, fade:0.025, grain:0.13, monochrome:false),
        .init(id:"ultramax400", title:"Ultramax 400", family:"Color Negative", saturation:1.12, contrast:1.08, brightness:0, warmth:0.025, fade:0.01, grain:0.16, monochrome:false),
        .init(id:"pro400h", title:"Pro 400H", family:"Color Negative", saturation:0.78, contrast:0.88, brightness:0.035, warmth:0.015, fade:0.07, grain:0.09, monochrome:false),
        .init(id:"velvia50", title:"Velvia 50", family:"Slide", saturation:1.35, contrast:1.22, brightness:-0.01, warmth:0.01, fade:0, grain:0.025, monochrome:false),
        .init(id:"astia100f", title:"Astia 100F", family:"Slide", saturation:0.92, contrast:0.91, brightness:0.02, warmth:0.015, fade:0.025, grain:0.035, monochrome:false),
        .init(id:"superia400", title:"Superia 400", family:"Color Negative", saturation:1.04, contrast:1.03, brightness:0, warmth:-0.015, fade:0.015, grain:0.15, monochrome:false),
        .init(id:"documentary", title:"Classic Documentary", family:"Muted Color", saturation:0.72, contrast:1.05, brightness:0, warmth:-0.005, fade:0.025, grain:0.08, monochrome:false),
        .init(id:"tungsten800", title:"Tungsten 800", family:"Cinema", saturation:0.88, contrast:1.12, brightness:-0.015, warmth:-0.075, fade:0, grain:0.19, monochrome:false),
        .init(id:"cinema400d", title:"Cinema 400D", family:"Cinema", saturation:0.94, contrast:0.98, brightness:0.01, warmth:0.025, fade:0.025, grain:0.10, monochrome:false),
        .init(id:"hp5", title:"HP5 Plus", family:"Black & White", saturation:0, contrast:1.12, brightness:0, warmth:0, fade:0.01, grain:0.18, monochrome:true),
        .init(id:"delta3200", title:"Delta 3200", family:"Black & White", saturation:0, contrast:1.28, brightness:-0.015, warmth:0, fade:0, grain:0.30, monochrome:true),
        .init(id:"trix400", title:"Tri-X 400", family:"Black & White", saturation:0, contrast:1.18, brightness:0, warmth:0, fade:0.015, grain:0.22, monochrome:true)
    ]

    static let portra400 = all[0]
}
