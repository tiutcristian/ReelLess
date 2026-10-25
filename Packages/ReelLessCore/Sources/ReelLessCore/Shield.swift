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
    function post(u,h){try{window.webkit.messageHandlers.\(bridgeName).postMessage({type:'route',url:String(u),history:!!h});}catch(e){}}
    function resolve(u){try{return new URL(u,location.href);}catch(e){return null;}}
    """

    /// Stops swiping from one reel to the next without depending on Instagram's markup.
    /// While the lock is on it swallows swipe/wheel/key gestures before the page's own handlers
    /// see them, and pins every scroll container around a video where it was once the reel
    /// settled, so neither a swipe nor an auto-advance can bring the next reel into view.
    /// Taps still go through, so play, pause and unmute keep working.
    /// `reelLock(true)` is always on (viewer); `reelLock(false)` turns on only while a video
    /// covers at least 40% of the screen, which is a reel or story player, never the chat.
    private static let reelLock = """
    function bigVideo(){var vs=document.getElementsByTagName('video'),W=innerWidth,H=innerHeight;for(var i=0;i<vs.length;i++){var r=vs[i].getBoundingClientRect();var w=Math.min(r.right,W)-Math.max(r.left,0),h=Math.min(r.bottom,H)-Math.max(r.top,0);if(w>0&&h>0&&w*h>=0.4*W*H){return true;}}return false;}
    function reelLock(always){
      var since=null,snapped=false,touched=false,pinned=new WeakMap(),settle=always?1500:600;
      function on(){return always||bigVideo();}
      function snapshot(){
        var els=[document.scrollingElement],vs=document.getElementsByTagName('video');
        for(var i=0;i<vs.length;i++){for(var n=vs[i].parentElement;n;n=n.parentElement){els.push(n);}}
        els.forEach(function(el){if(el&&!pinned.has(el)&&(el.scrollHeight>el.clientHeight||el.scrollWidth>el.clientWidth)){pinned.set(el,[el.scrollLeft,el.scrollTop]);}});
      }
      function tick(){
        if(on()){
          if(since===null){since=Date.now();snapped=false;}
          if(!snapped&&((always&&touched)||Date.now()-since>=settle)){snapshot();snapped=true;}
        }else if(since!==null){since=null;snapped=false;pinned=new WeakMap();}
      }
      setInterval(tick,150);
      function swallow(e){if(on()){e.preventDefault();e.stopPropagation();}}
      ['touchmove','wheel','gesturestart','gesturechange'].forEach(function(t){window.addEventListener(t,swallow,{capture:true,passive:false});});
      window.addEventListener('pointermove',function(e){if(e.pointerType==='touch'&&on()){e.stopPropagation();}},true);
      window.addEventListener('touchstart',function(){touched=true;tick();},{capture:true,passive:true});
      window.addEventListener('keydown',function(e){
        if(['ArrowDown','ArrowUp','PageDown','PageUp','Home','End',' '].indexOf(e.key)>=0&&!/^(INPUT|TEXTAREA)$/.test(e.target.tagName)){swallow(e);}
      },true);
      document.addEventListener('scroll',function(e){
        tick();
        if(!snapped){return;}
        var el=(e.target===document||e.target===document.documentElement)?document.scrollingElement:e.target;
        if(!el||el.nodeType!==1){return;}
        var p=pinned.get(el);
        if(!p){pinned.set(el,[el.scrollLeft,el.scrollTop]);return;}
        if(el.scrollLeft!==p[0]){el.scrollLeft=p[0];}
        if(el.scrollTop!==p[1]){el.scrollTop=p[1];}
      },true);
    }
    """

    /// Inbox web view: hide the doors, guard in-page (SPA) route changes, and lock any reel
    /// player Instagram opens inside the conversation.
    public static func mainScript(pack: RulePack) -> String {
        let css = pack.hideCSS.map { "\($0) { display: none !important; }" }.joined(separator: "\n")
        return """
        (function(){
        if(window.__rl){return;}window.__rl=true;
        \(injectCSS)\(post)
        injectCSS(\(json(css))+'\\n*{scroll-behavior:auto !important;}');
        var allow=\(json(pack.allow)).map(function(s){return new RegExp(s);});
        function ok(u){var r=resolve(u);if(!r||r.origin!==location.origin){return true;}return allow.some(function(re){return re.test(r.pathname);});}
        ['pushState','replaceState'].forEach(function(k){
          var orig=history[k];
          history[k]=function(s,t,u){if(u!=null&&!ok(u)){var r=resolve(u);post(r?r.href:u,true);return;}return orig.apply(this,arguments);};
        });
        document.addEventListener('click',function(e){
          var a=e.target&&e.target.closest?e.target.closest('a[href]'):null;if(!a){return;}
          var r=resolve(a.getAttribute('href'));if(!r){return;}
          if(['http:','https:','mailto:','tel:'].indexOf(r.protocol)<0){return;}
          if(r.origin!==location.origin||!ok(r.href)){e.preventDefault();e.stopPropagation();post(r.href);}
        },true);
        \(reelLock)
        reelLock(false);
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
        injectCSS(\(json(css))+'\\n*{scroll-behavior:auto !important;}');
        var code=/^\\/(?:p|reel|reels|tv)\\/([A-Za-z0-9_-]+)\\/?$/;
        function same(path){var a=code.exec(path),b=code.exec(location.pathname);return a&&b?a[1]===b[1]:path===location.pathname;}
        ['pushState','replaceState'].forEach(function(k){
          var orig=history[k];
          history[k]=function(s,t,u){var r=u==null?null:resolve(u);if(r&&!same(r.pathname)){return;}return orig.apply(this,arguments);};
        });
        document.addEventListener('click',function(e){
          var a=e.target&&e.target.closest?e.target.closest('a[href]'):null;
          if(a){e.preventDefault();e.stopPropagation();}
        },true);
        \(reelLock)
        reelLock(true);
        })();
        """
    }
}

public struct RouteMessage: Equatable {
    public let url: URL
    /// The page tried to change its own URL (pushState/replaceState) rather than follow a link,
    /// so it may already be rendering that route.
    public let fromHistory: Bool
}

public enum BridgeMessage {
    /// Accepts only `{type: "route", url: <string>, history?: <bool>}`; anything else is dropped.
    public static func parseRoute(_ body: Any) -> RouteMessage? {
        guard let dict = body as? [String: Any],
              dict["type"] as? String == "route",
              let raw = dict["url"] as? String,
              raw.count < 4096,
              let url = URL(string: raw) else { return nil }
        return RouteMessage(url: url, fromHistory: dict["history"] as? Bool ?? false)
    }
}
