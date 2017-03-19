//
//  ViewController.swift
//  GetVoice
//
//  Created by 松居 麻衣 on 2017/03/04.
//  Copyright © 2017年 松居 麻衣. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    var startButton : UIButton = UIButton()
    var textView : UITextView = UITextView()
    var resultTextView : UITextView = UITextView()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionTask : SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        
        startButton.isEnabled = false
        
        startButton.frame = CGRect(x: 10, y: 50, width: displayWidth-20, height: 50)
        startButton.addTarget(self, action: #selector(ViewController.onClickStartButton(sender:)), for: .touchUpInside)
        self.startButton.setTitle("ボタンを押すと録音が開始します", for: [])
        
        textView = UITextView(frame: CGRect(x: 10, y: 100, width: displayWidth-20, height: 50))
        textView.text = "音声を入力してください"
        
        resultTextView = UITextView(frame: CGRect(x: 10, y: 300, width: displayWidth-20, height: 50))
        resultTextView.text = "結果"
        
        self.view.addSubview(startButton)
        self.view.addSubview(textView)
        self.view.addSubview(resultTextView)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        do{
            SFSpeechRecognizer.requestAuthorization { (status) in
                OperationQueue.main.addOperation {
                    switch status {
                    case .authorized:   // 許可OK
                        self.startButton.isEnabled = true
                        self.startButton.backgroundColor = UIColor.blue
                    case .denied:       // 拒否
                        self.startButton.isEnabled = false
                        self.startButton.setTitle("録音許可なし", for: .disabled)
                    case .restricted:   // 限定
                        self.startButton.isEnabled = false
                        self.startButton.setTitle("このデバイスでは無効", for: .disabled)
                    case .notDetermined:// 不明
                        self.startButton.isEnabled = false
                        self.startButton.setTitle("録音機能が無効", for: .disabled)
                    }
                }
            }
            
        } catch {
            
        }
        
    }
    
    private func startRecording() throws {
        if let recognitionTask = recognitionTask{
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("リクエスト生成エラー") }
        recognitionRequest.shouldReportPartialResults = true
        
        guard let inputNode = audioEngine.inputNode else { fatalError("InputNodeエラー") }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest){(result, error) in
            var isFinal = false
            if let result = result {
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus:0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.startButton.isEnabled = true
                self.startButton.setTitle("Start Recording", for: [])
                self.startButton.backgroundColor = UIColor.blue
                
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()   // オーディオエンジン準備
        try audioEngine.start() // オーディオエンジン開始
        print("認識します")
        
        textView.text = "(認識中…そのまま話し続けてください)"
        
    }
    
    
    
    
    func onClickStartButton(sender: UIButton){
        if audioEngine.isRunning {
            // 音声エンジン動作中なら停止
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startButton.isEnabled = false
            startButton.setTitle("Stopping", for: .disabled)
            startButton.backgroundColor = UIColor.lightGray
            let voice = self.textView.text
            
            if let voice = voice {
                let getVoice = voice
                print(getVoice)
                let jsonVoice = createJson(getVoice: getVoice)
                // self.sendParameter(getVoice: getVoice)
                
                let urlStr = "http://46.101.200.35:80/post"
//                urlStr = urlStr + getVoice
                // let urlStrUtf8 : String.UTF8View = urlStr.utf8
                let request = NSMutableURLRequest(url: NSURL(string: urlStr)! as URL)
                
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpMethod = "POST"
                
                request.httpBody = jsonVoice
                
                let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
                    
                    if(error == nil){
                        let parseTitle = self.parseJSON(jsonData: data!)
                        print(parseTitle)
                        
                        
                    } else {
                        print(error!)
                    }
                    
                })
                task.resume()
            }
            
            //self.resultTextView.text = result as String!
            //self.view.addSubview(resultTextView)
            
            
            
            return
        }
        // 録音を開始する
        print("ボタン押された")
        try! startRecording()
        startButton.setTitle("認識を完了する", for: [])
        startButton.backgroundColor = UIColor.red
    }
    
    public func speechRecognizer (_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool){
        if available {
            startButton.isEnabled = true
            startButton.setTitle("Start Recording", for: [])
            
        } else {
            startButton.isEnabled = false
            startButton.setTitle("現在、使用不可", for: .disabled)
        }
    }
    

    
    
    func createJson(getVoice : String) -> Data?{
        let dictionary = ["data":getVoice]
        var bodyData: Data?
        do {
            bodyData = try JSONSerialization.data(withJSONObject: dictionary,
                                                  options: .prettyPrinted)
        } catch {
            // TODO Error handling
            print("json serialization error")
        }

        return bodyData
    }
    
    func parseJSON(jsonData : Data) -> [[String : String]]{
        var result : [Any] = []
        
        let json = JSON(data: jsonData)
        var count = 0
        for _ in json {
            var title : String = ""
            var info : String = ""
            title = json["result"][count]["title"].string!
            print(title)
            info = json["result"][count]["info"].string!
            print(info)
            
            let item = ["title" : title, "info" : info]
            
            result.append(item)
            count = count + 1
        }
        
        
        return result as! [[String : String]]
    }
    
    
    
}

