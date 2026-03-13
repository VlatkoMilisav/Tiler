import Foundation

struct GridProfile: Codable, Equatable {
    var name: String
    var columns: Int
    var rows: Int

    static let defaults: [GridProfile] = [
        GridProfile(name: "Sixty Forty (60×40)", columns: 60, rows: 40),
        GridProfile(name: "Halves (2×1)",      columns: 2,  rows: 1),
        GridProfile(name: "Quarters (2×2)",    columns: 2,  rows: 2),
        GridProfile(name: "Thirds (3×2)",      columns: 3,  rows: 2),
        GridProfile(name: "Standard (4×3)",    columns: 4,  rows: 3),
        GridProfile(name: "Widescreen (6×3)",  columns: 6,  rows: 3),
        GridProfile(name: "Fine (6×4)",        columns: 6,  rows: 4),
        GridProfile(name: "Classic (12×12)",   columns: 12, rows: 12),
        GridProfile(name: "Widescreen (16×9)", columns: 16, rows: 9),
    ]
}
 