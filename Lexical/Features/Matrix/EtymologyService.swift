import Foundation
import SwiftData
import LexicalCore

/// Service to resolve etymological roots for vocabulary items
public final class EtymologyService {
    
    /// Static mapping of common English roots for demonstration/MVP
    private static let rootMap: [String: String] = [
        // spec/spect = look
        "inspect": "spect",
        "spectacle": "spect",
        "perspective": "spect",
        "prospect": "spect",
        "aspect": "spect",
        "retrospect": "spect",
        "speculate": "spect",
        
        // fer = carry
        "transfer": "fer",
        "refer": "fer",
        "prefer": "fer",
        "confer": "fer",
        "infer": "fer",
        "defer": "fer",
        "offer": "fer",
        
        // port = carry
        "transport": "port",
        "import": "port",
        "export": "port",
        "deport": "port",
        "report": "port",
        "support": "port",
        
        // tract = pull
        "attract": "tract",
        "detract": "tract",
        "contract": "tract",
        "extract": "tract",
        "retract": "tract",
        "subtract": "tract",
        
        // ject = throw
        "eject": "ject",
        "inject": "ject",
        "project": "ject",
        "reject": "ject",
        "subject": "ject",
        "object": "ject"
    ]
    
    /// Resolve the root for a given lemma
    public static func resolveRoot(for lemma: String) -> String? {
        // Direct lookup
        if let root = rootMap[lemma.lowercased()] {
            return root
        }
        
        // Suffix matching (basic heuristic)
        for (word, root) in rootMap {
            if lemma.hasSuffix(root) && lemma.count > root.count + 2 {
                return root
            }
        }
        
        return nil
    }
    
    /// Get all known words for a root
    public static func wordsForRoot(_ root: String) -> [String] {
        return rootMap.filter { $0.value == root }.map { $0.key }
    }
}
