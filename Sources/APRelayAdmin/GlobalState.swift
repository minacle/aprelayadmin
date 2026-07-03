import Observation
import RetortTUI

@Observable
final class GlobalState {

    var adminToken: String = ""

    var relayURL: String = ""
}
