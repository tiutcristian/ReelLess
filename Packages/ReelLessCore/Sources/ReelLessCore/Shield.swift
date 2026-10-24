import Foundation

/// Builds the scripts injected at document start. Both are generated from the rule pack.
public enum Shield {
    public static let bridgeName = "reelless"

    private static func json<T: Encodable>(_ value: T) -> String {
        let data = (try? JSONEncoder().encode(value)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private static let injectCSS = """
    function injectCSS(css){var s=document.createElement('style');s.textContent=css;(document.head||document.documentElement).appendChild(s);}
    """

    private static let post = """
    function post(u){try{window.webkit.messageHandlers.\(bridgeName).postMessage({type:'route',url:String(u)});}catch(e){}}
    function resolve(u){try{return new URL(u,location.href);}catch(e){return null;}}
    """

    /// Inbox web view: hide the doors, and guard in-page (SPA) route changes.
    public static func mainScript(pack: RulePack) -> String {
        let css = pack.hideCSS.map { "\($0) { display: none !important; }" }.joined(separator: "\n")
        return """
        (function(){
        if(window.__rl){return;}window.__rl=true;
        \(injectCSS)\(post)
        injectCSS(\(json(css)));
        var allow=\(json(pack.allow)).map(function(s){return new RegExp(s);});
        function ok(u){var r=resolve(u);if(!r||r.origin!==location.origin){return true;}return allow.some(function(re){return re.test(r.pathname);});}
        ['pushState','replaceState'].forEach(function(k){
          var orig=history[k];
          history[k]=function(s,t,u){if(u!=null&&!ok(u)){var r=resolve(u);post(r?r.href:u);return;}return orig.apply(this,arguments);};
        });
        document.addEventListener('click',function(e){
          var a=e.target&&e.target.closest?e.target.closest('a[href]'):null;if(!a){return;}
          var r=resolve(a.getAttribute('href'));if(!r){return;}
          if(['http:','https:','mailto:','tel:'].indexOf(r.protocol)<0){return;}
          if(r.origin!==location.origin||!ok(r.href)){e.preventDefault();e.stopPropagation();post(r.href);}
        },true);
        })();
        """
    }

    /// Viewer web view: no link leaves the item, no in-page navigation, no scrolling on.
    public static func viewerScript(pack: RulePack) -> String {
        let css = pack.viewerCSS.joined(separator: "\n")
        return """
        (function(){
        if(window.__rl){return;}window.__rl=true;
        \(injectCSS)\(post)
        injectCSS(\(json(css)));
        var here=location.pathname;
        ['pushState','replaceState'].forEach(function(k){
          var orig=history[k];
          history[k]=function(s,t,u){var r=u==null?null:resolve(u);if(r&&r.pathname!==here){return;}return orig.apply(this,arguments);};
        });
        document.addEventListener('click',function(e){
          var a=e.target&&e.target.closest?e.target.closest('a[href]'):null;
          if(a){e.preventDefault();e.stopPropagation();}
        },true);
        })();
        """
    }
}

public enum BridgeMessage {
    /// Accepts only `{type: "route", url: <string>}`; anything else is dropped.
    public static func parseRoute(_ body: Any) -> URL? {
        guard let dict = body as? [String: Any],
              dict["type"] as? String == "route",
              let raw = dict["url"] as? String,
              raw.count < 4096,
              let url = URL(string: raw) else { return nil }
        return url
    }
}
