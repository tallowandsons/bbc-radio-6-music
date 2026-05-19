import Foundation
import Combine

struct ScheduledShow {
    let name: String
    let start: Date
    let end: Date

    var formattedTimeRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }
}

class ScheduleService: ObservableObject {
    @Published private(set) var currentShow: ScheduledShow?

    private var timer: Timer?
    private let url = URL(string: "https://rms.api.bbc.co.uk/v2/experience/inline/schedules/bbc_6music")!

    func start() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    private func fetch() {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modules = json["data"] as? [[String: Any]],
                  let items = modules.first?["data"] as? [[String: Any]] else { return }

            let iso = ISO8601DateFormatter()
            let now = Date()

            let show = items.compactMap { item -> ScheduledShow? in
                guard let startStr = item["start"] as? String,
                      let endStr   = item["end"]   as? String,
                      let titles   = item["titles"] as? [String: Any],
                      let name     = titles["primary"] as? String,
                      let start    = iso.date(from: startStr),
                      let end      = iso.date(from: endStr)
                else { return nil }
                return ScheduledShow(name: name, start: start, end: end)
            }.first { $0.start <= now && now < $0.end }

            DispatchQueue.main.async { self?.currentShow = show }
        }.resume()
    }
}
