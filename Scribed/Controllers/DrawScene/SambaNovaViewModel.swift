import Foundation

class SambaNovaViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var results: String = ""
    
    private let sambaKey: String
    private let folderPath: String = "/test_docs/"
    
    init() {
        // Load environment variables
        self.sambaKey = ProcessInfo.processInfo.environment["SAMBANOVA_API_KEY"] ?? "3ed221bc-8d7f-4425-82c2-32f1f77461bc"
    }
    
    func search() {
        let texts = loadTextFiles(from: folderPath)
        let results = processTexts(texts: texts, topic: searchText)
        
        // Introduce a delay before calling consolidateResultsAndRefine
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let finalResults = self.consolidateResultsAndRefine(results: results, topic: self.searchText, texts: texts)

            // Use finalResults as needed
            DispatchQueue.main.async {
                self.results = self.formatResults(finalResults)
            }
        }
    }
    
    private func processTexts(texts: [String: String], topic: String) -> [String: String] {
        print("Getting Results")

        var results = [String: String]()
        let url = URL(string: "https://api.sambanova.ai/v1/chat/completions")!
        
        let group = DispatchGroup()  // Used to wait for all network calls to complete
        
        for (filename, text) in texts {
            let prompt = createPrompt(text: text, query: topic)
            let body: [String: Any] = [
                "model": "Meta-Llama-3.1-8B-Instruct",
                "messages": [
                    ["role": "system", "content": "You are a helpful assistant."],
                    ["role": "user", "content": "Text: \(text)\n\nThis is my prompt: \(prompt)"]
                ],
                "temperature": 0.1,
                "top_p": 0.1
            ]
            
            group.enter()  // Enter the group for each API request
            
            makeHTTPRequest(url: url, apiKey: sambaKey, body: body) { data, response, error in
                if let data = data {
                    do {
                        // Parse the JSON response
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let choices = jsonResponse["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            print("Extracted Content: \(content)")
                            
                            // Update your results dictionary with the extracted content
                            results[filename] = content
                        } else {
                            print("Unexpected JSON structure.")
                        }
                    } catch {
                        print("Error parsing JSON: \(error)")
                    }
                } else if let error = error {
                    print("Error: \(error)")
                }
                
                group.leave()  // Leave the group when the network request is finished
            }
        }
        
//        // Wait for all network calls to complete before updating the UI
//        group.notify(queue: .main) {
//            // Once all requests are done, show the results in a dialog box
//            self.showResultsAlert(results: results)
//        }
        
        return results
    }

    
    private func createPrompt(text: String, query: String) -> String {
            let relevancePrompt = "Question: Is the topic '\(query)' discussed in this text at all? If so, rate the level of relevance. Answer with 'yes (definitely)' or 'yes (moderately)' or 'yes (barely)' or 'no'.  Additionally, provide a timestamp in (mm:ss) format for the sentences/section as if we were indexing the text like it was a video transcript."
            return "\(text)\n\n\(relevancePrompt)"
        }
    
    private func consolidateResultsAndRefine(results: [String: String], topic: String, texts: [String: String]) -> [String: String] {
        
        print("Getting conslidate results and refine")

        var categorizedResults: [String: [String]] = [
            "definitely": [],
            "moderately": [],
            "barely": [],
            "not_mentioned": []
        ]
        
        var detailedResults = [String: String]()
        
        for (filename, result) in results {
            let resultLower = result.lowercased()
            if resultLower.contains("yes (definitely)") {
                categorizedResults["definitely"]?.append(filename)
            } else if resultLower.contains("yes (moderately)") {
                categorizedResults["moderately"]?.append(filename)
            } else if resultLower.contains("yes (barely)") {
                categorizedResults["barely"]?.append(filename)
            } else {
                categorizedResults["not_mentioned"]?.append(filename)
            }
        }
        
        for category in ["definitely", "moderately", "barely"] {
            for filename in categorizedResults[category] ?? [] {
                let refinedResult = refineWithSambaNova(text: texts[filename] ?? "", topic: topic)
                detailedResults[filename] = refinedResult
            }
        }
        
        print(detailedResults)
        return detailedResults
    }
    
    private func refineWithSambaNova(text: String, topic: String) -> String {
        let prompt = "Text: \(text)\n\nQuestion: Identify the sentences or areas where the topic '\(topic)' is discussed, even if mentioned indirectly. Provide the relevant sentences or sections, but limit the response to unique sentences or sections. The section should not be too large. Additionally, provide a timestamp in (mm:ss) format for the sentences/section as if we were indexing the text like it was a video transcript."
        
        let url = URL(string: "https://api.sambanova.ai/v1/chat/completions")!
        var refinedResult = ""
        
        let body: [String: Any] = [
            "model": "Meta-Llama-3.1-70B-Instruct",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": "Text: \(text)\n\nThis is my prompt: \(prompt)"]
            ],
            "temperature": 0.1,
            "top_p": 0.1
        ]
        
        makeHTTPRequest(url: url, apiKey: sambaKey, body: body) { data, response, error in
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                refinedResult = responseString
            }
        }
        
        return refinedResult
    }
    
//    private func loadTextFiles(folderName: String) -> [String: String] {
//        var texts = [String: String]()
//        let fileNames = ["/Users/julienne/Documents/scribed/scribed/Controllers/DrawScene/Apple.txt", "Scribed/Controllers/DrawScene/OpenAI.txt"]
//        
//        print(FileManager.default.currentDirectoryPath)
//
//        for fileName in fileNames {
//            if let content = try? String(contentsOfFile: fileName, encoding: .utf8) {
//                print(content)
//                texts[fileName] = content
//            }
//        }
//        
//        print("Returning Texts")
//        print(texts)
//        return texts
//    }
    
    private func loadTextFiles(from folderPath: String) -> [String: String] {
         var texts = [String: String]()
//         let fileManager = FileManager.default
//         let fileNames = "Users/julienne/Documents/scribed/scribed/Controllers/DrawScene/docs"
//         do {
//             let files = try fileManager.contentsOfDirectory(atPath: fileNames)
//             for file in files where file.hasSuffix(".txt") {
//                 let filePath = "\(folderPath)/\(file)"
//                 if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
//                     print(content)
//                     texts[file] = content
//                 }
//             }
//         } catch {
//             print("Error reading directory: \(error)")
//         }
//        print(texts)
        texts["Lecture 1"] = "Binary search is an efficient algorithm for finding the position of a target value within a sorted array. It works by repeatedly dividing the search interval in half: starting with the entire array, it compares the middle element to the target. If the middle element matches the target, the search is complete. If the target is smaller, the search continues in the left half; if larger, in the right half. This process repeats until the target is found or the interval is empty. With a time complexity of O(logn), binary search is much faster than linear search for large datasets, but it requires the input to be sorted."
        texts["Lecture 2"] = "Time complexity measures the amount of time an algorithm takes to complete as a function of the input size, ( n ). It helps evaluate the efficiency of an algorithm, especially as ( n ) grows large. Common notations include ( O(1) ) for constant time, ( O(log n) ) for logarithmic time, ( O(n) ) for linear time, ( O(n log n) ) for linearithmic time, and ( O(n^2) ) for quadratic time. These describe the upper bound of an algorithm’s growth rate, focusing on the dominant term while ignoring constants and lower-order terms. Understanding time complexity ensures optimal performance, particularly when processing large datasets."
        
        return texts
     }
private func makeHTTPRequest(url: URL, apiKey: String, body: [String: Any], completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
        print("Error serializing JSON: \(error)")
        return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error)")
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Response Status Code: \(httpResponse.statusCode)")
        }
        
        if let data = data {
            if let responseString = String(data: data, encoding: .utf8) {
                print("SambaNova Response Data: \(responseString)")
            } else {
                print("Failed to decode response data")
            }
        }
        
        // Call the completion handler
        completion(data, response, error)
    }
    task.resume()
}
    
    private func formatResults(_ results: [String: String]) -> String {
        var formattedResults = ""
        for (filename, result) in results {
            formattedResults += "File: \(filename)\n - \(result)\n"
        }
        return formattedResults
    }
}
