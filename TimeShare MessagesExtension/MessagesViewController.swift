//
//  MessagesViewController.swift
//  TimeShare MessagesExtension
//
//  Created by Stanly Shiyanovskiy on 04.10.2020.
//

import UIKit
import Messages

public final class MessagesViewController: MSMessagesAppViewController {
    
    public override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        if presentationStyle == .expanded {
            displayEventViewController(conversation: activeConversation, identifier: "CreateEvent")
        }
    }
    
    public override func willBecomeActive(with conversation: MSConversation) {
        if presentationStyle == .expanded {
            displayEventViewController(conversation: conversation, identifier: "SelectDates")
        }
    }
    
    private func displayEventViewController(conversation: MSConversation?, identifier: String) {
        // 0: sanity check, is there a conversation?
        guard let conversation = conversation else { return }

        // 1: create the child view controller
        guard let vc = storyboard?.instantiateViewController(withIdentifier: identifier) as? EventViewController else { return }

        vc.delegate = self
        vc.load(from: conversation.selectedMessage)

        // 2: add the child to the parent so that events are forwarded
        addChild(vc)

        // 3: give the child a meaningful frame: make it fill our view
        vc.view.frame = view.bounds
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)

        // 4: add Auto Layout constraints so the child view continues to fill the full view
        vc.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        vc.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        vc.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        // 5: tell the child it has now moved to a new parent view controller
        vc.didMove(toParent: self)
    }
    
    public func createMessage(with dates: [Date], votes: [Int]) {
        // 1: return the extension to compact mode
        requestPresentationStyle(.compact)

        // 2: do a quick sanity check to make sure we have a conversation to work with
        guard let conversation = activeConversation else { return }

        // 3: convert all our dates and votes into URLQueryItem objects
        var components = URLComponents()
        var items = [URLQueryItem]()

        for (index, date) in dates.enumerated() {
            let dateItem = URLQueryItem(name: "date-\(index)", value: string(from: date))
            items.append(dateItem)

            let voteItem = URLQueryItem(name: "vote-\(index)", value: String(votes[index]))
            items.append(voteItem)
        }

        components.queryItems = items

        // 4: use the existing session or create a new one
        let session = conversation.selectedMessage?.session ?? MSSession()

        // 5: create a new message from the session and assign it the URL we created from our dates and votes
        let message = MSMessage(session: session)
        message.url = components.url

        // 6: create a blank, default message layout
        let layout = MSMessageTemplateLayout()
        layout.image = render(dates: dates)
        layout.caption = "I voted"
        message.layout = layout

        // 7: insert it into the conversation with the change message "Votes added"
        conversation.insert(message) { error in
            if let error = error {
                print(error)
            }
        }
    }
    
    private func render(dates: [Date]) -> UIImage {
        // define our 20-point padding
        let inset: CGFloat = 20

        // create the attributes for drawing using Dynamic Type so that we respect the user's font choices
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body), NSAttributedString.Key.foregroundColor: UIColor.darkGray]

        // make a single string out of all the dates
        var stringToRender = ""

        dates.forEach {
            stringToRender += DateFormatter.localizedString(from: $0, dateStyle: .long, timeStyle: .short) + "\n"
        }

        // trim the last line break, then create an attributed string by merging the date string and the attributes
        let trimmed = stringToRender.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributedString = NSAttributedString(string: trimmed, attributes: attributes)

        // calculate the size required to draw the attributed string, then add the inset to all edges
        var imageSize = attributedString.size()
        imageSize.width += inset * 2
        imageSize.height += inset * 2

        // create an image format that uses @3x scale on an opaque background
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3

        // create a renderer at the correct size, using the above format
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

        // render a series of instructions to `image`
        let image = renderer.image { ctx in
            // draw a solid white background
            UIColor.white.set()
            ctx.fill(CGRect(origin: CGPoint.zero, size: imageSize))

            // now render our text on top, using the insets we created
            attributedString.draw(at: CGPoint(x: inset, y: inset))
        }

        // send the resulting image back
        return image
    }
    
    private func string(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return dateFormatter.string(from: date)
    }

    // MARK: - Actions
    @IBAction private func createNewEvent(_ sender: AnyObject) {
        requestPresentationStyle(.expanded)
    }
}
