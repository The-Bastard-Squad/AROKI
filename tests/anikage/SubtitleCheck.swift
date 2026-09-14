import Foundation
import VireoCore

struct FixtureTransport: HTTPTransport {
    let response: Data
    func execute(_ request: URLRequest, redirectPolicy: RedirectPolicy, maxResponseBytes: Int) async throws -> TransportResponse {
        guard let url = request.url else { throw EngineError.network("missing URL") }
        let data = url.host == "og.bakayaro.live" ? Data("WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nFixture caption\n".utf8) : response
        guard data.count <= maxResponseBytes else { throw EngineError.responseTooLarge(limit: maxResponseBytes) }
        return TransportResponse(data:data,statusCode:200,finalURL:url,headers:[:])
    }
}

@main struct SubtitleCheck {
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw EngineError.parse(message) }
    }
    static func output(_ data: [String:Any]) {
        if let bytes = try? JSONSerialization.data(withJSONObject:data,options:[.sortedKeys]), let text = String(data:bytes,encoding:.utf8) { print(text) }
    }
    static func main() async {
        do {
            let args=CommandLine.arguments
            let baseline=try ConnectorValidator.validate(manifestData:Data(contentsOf:URL(fileURLWithPath:args[1])))
            let candidate=try ConnectorValidator.validate(manifestData:Data(contentsOf:URL(fileURLWithPath:args[2])))
            let tracks:[[String:Any]]=[
                ["file":"fixture/english.vtt","label":"English","kind":"captions"],
                ["file":"fixture/french.vtt","label":"French","srclang":"fr","kind":"captions"],
                ["label":"missing file"]
            ]
            func response(_ tracks:[[String:Any]]) throws -> Data {
                try JSONSerialization.data(withJSONObject:["sources":[["url":"fixture/master.m3u8","quality":"auto"]],"subtitles":tracks])
            }
            for variant in [AudioVariant.sub,.dub] {
                let transport=FixtureTransport(response:try response(tracks))
                let old=try await ConnectorEngine(manifest:baseline,transport:transport).streams(titleID:"fixture",episodeID:"1",variant:variant)
                let engine=ConnectorEngine(manifest:candidate,transport:transport)
                let new=try await engine.streams(titleID:"fixture",episodeID:"1",variant:variant)
                try require(old.count==1 && new.count==1,"video count changed")
                try require(old[0].url==new[0].url && old[0].headers==new[0].headers,"video route/headers changed")
                try require(old[0].subtitles.isEmpty && new[0].subtitles.count==2,"subtitle mapping regression")
                try require(new[0].subtitles[0].label=="English" && new[0].subtitles[1].languageCode=="fr","language labels changed")
                try require(new[0].subtitles[0].url.absoluteString=="https://og.bakayaro.live/fixture/english.vtt","relative caption base incorrect")
                let cues=try await engine.loadSubtitleTrack(new[0].subtitles[0],headers:new[0].headers)
                try require(cues.count==1 && cues[0].start==1 && cues[0].end==3,"native VTT parser failed")
                let absent=try await ConnectorEngine(manifest:candidate,transport:FixtureTransport(response:try response([]))).streams(titleID:"fixture",episodeID:"1",variant:variant)
                try require(absent.count==1 && absent[0].subtitles.isEmpty,"no-caption response broke video")
                output(["stage":"fixture","variant":variant.rawValue,"result":"passed","checks":7])
            }
            if args.contains("--fixtures-only") { return }
            let engine=ConnectorEngine(manifest:candidate,transport:URLSessionTransport(timeoutSeconds:20))
            for query in ["ONE PIECE","Sword Art Online"] {
                let results=try await engine.search(query:query)
                guard let title=results.first(where:{$0.title.caseInsensitiveCompare(query) == .orderedSame}) else { throw EngineError.parse("exact title missing") }
                for variant in [AudioVariant.sub,.dub] {
                    do {
                        let candidates=try await engine.streams(titleID:title.sourceID,episodeID:"1",variant:variant)
                        guard let stream=candidates.first else { throw EngineError.noPlayableStream }
                        let media=try await engine.probeStream(stream)
                        var cueCount=0
                        var first:Double = -1
                        if let english=stream.subtitles.first(where:{$0.label?.localizedCaseInsensitiveContains("English") == true}) ?? stream.subtitles.first {
                            let cues=try await engine.loadSubtitleTrack(english,headers:stream.headers)
                            cueCount=cues.count; first=cues.first?.start ?? -1
                        }
                        output(["stage":"live","title":title.title,"episode":1,"variant":variant.rawValue,"candidates":candidates.count,"captionTracks":stream.subtitles.count,"labels":stream.subtitles.compactMap(\.label),"nativeParsedCues":cueCount,"firstCueSeconds":first,"hls":media.starts(with:Data("#EXTM3U".utf8)),"result":cueCount>0 ? "captions-parsed" : "no-captions-supplied"])
                    } catch {
                        output(["stage":"live","title":title.title,"episode":1,"variant":variant.rawValue,"result":"failed","errorType":String(describing:type(of:error))])
                    }
                }
            }
        } catch {
            output(["stage":"harness","result":"failed","errorType":String(describing:type(of:error))])
            exit(1)
        }
    }
}
