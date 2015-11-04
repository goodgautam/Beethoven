import Accelerate
import AVFoundation

public protocol PitchDetectorDelegate: class {
  func pitchDetectorDidUpdateFrequency(pitchDetector: PitchDetector, frequency: Float)
}

public class PitchDetector {

  public weak var delegate: PitchDetectorDelegate?

  private var sampleRate: Float
  private var bufferSize: AVAudioFrameCount

  // MARK: - Initialization

  public init(sampleRate: Float,
    bufferSize: AVAudioFrameCount,
    delegate: PitchDetectorDelegate? = nil) {
      self.sampleRate = sampleRate
      self.bufferSize = bufferSize
      self.delegate = delegate
  }

  // MARK: - Reading

  public func readBuffer(buffer: AVAudioPCMBuffer) {
    let frameCount = buffer.frameLength
    let log2n = UInt(round(log2(Double(frameCount))))
    let bufferSizePOT = Int(1 << log2n)
    let inputCount = bufferSizePOT / 2
    let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))

    var realp = [Float](count: inputCount, repeatedValue: 0)
    var imagp = [Float](count: inputCount, repeatedValue: 0)
    var output = DSPSplitComplex(realp: &realp, imagp: &imagp)

    vDSP_ctoz(UnsafePointer<DSPComplex>(buffer.floatChannelData.memory), 2,
      &output, 1, vDSP_Length(inputCount))
    vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))

    var magnitudes = [Float](count:inputCount, repeatedValue:0.0)
    vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))

    var normalizedMagnitudes = [Float](count: inputCount, repeatedValue: 0.0)
    vDSP_vsmul(sqrt(magnitudes), 1, [2.0 / Float(inputCount)],
      &normalizedMagnitudes, 1, vDSP_Length(inputCount))

    vDSP_destroy_fftsetup(fftSetup)

    if let maxMagnitude = normalizedMagnitudes.maxElement(),
      maxIndex = normalizedMagnitudes.indexOf(maxMagnitude) {
        let freq = Float(maxIndex) * sampleRate / Float(inputCount)
        delegate?.pitchDetectorDidUpdateFrequency(self, frequency: freq)
    }
  }

  // MARK: - Helpers

  private func sqrt(x: [Float]) -> [Float] {
    var results = [Float](count: x.count, repeatedValue: 0.0)
    vvsqrtf(&results, x, [Int32(x.count)])

    return results
  }
}
