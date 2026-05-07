import Foundation

/// The AudioCodecSettings class  specifying audio compression settings.
public struct AudioCodecSettings: Codable {
    /// The defualt value.
    public static let `default` = AudioCodecSettings()

    /// Specifies the bitRate of audio output.
    public var bitRate: UInt32 = 32 * 1000

    /// Specifies the number of channels. 0 means follow the input source.
    public var channels: UInt32 = 0

    /// Specifies the sample rate. 0 means follow the input source.
    public var sampleRate: Double = 0

    /// Create an new AudioCodecSettings instance.
    public init(bitRate: UInt32 = 32 * 1000, channels: UInt32 = 0, sampleRate: Double = 0) {
        self.bitRate = bitRate
        self.channels = channels
        self.sampleRate = sampleRate
    }
}
