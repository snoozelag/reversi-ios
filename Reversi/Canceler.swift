//
//  Canceler.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/05/05.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

final class Canceller {
    private(set) var isCancelled: Bool = false
    private let body: (() -> Void)?

    init(_ body: (() -> Void)?) {
        self.body = body
    }

    func cancel() {
        if isCancelled { return }
        isCancelled = true
        body?()
    }
}
