// 결 (Gyeol) — 단위 테스트 (Domain models)

import XCTest
@testable import GyeolDomain

final class DomainTests: XCTestCase {

    func testDomainOrder() {
        let order = DomainID.allCases.map { $0.indexNumber }
        XCTAssertEqual(order, [1, 2, 3, 4, 5, 6])
    }

    func testDomainLabels() {
        XCTAssertEqual(DomainID.belief.labelKo, "신념 체계")
        XCTAssertEqual(DomainID.intimacy.labelKo, "친밀함")
    }

    func testSkipReasonAll() {
        XCTAssertEqual(SkipReason.allCases.count, 4)
    }

    func testQualitativeLabels() {
        XCTAssertEqual(QualitativeLabel.alignment.labelKo, "결이 잘 맞음")
        XCTAssertEqual(QualitativeLabel.compromise.labelKo, "타협 가능")
        XCTAssertEqual(QualitativeLabel.boundary.labelKo, "경계 확인")
    }

    func testOpenQuestionsHaveAllDomains() {
        let domains = Set(OpenQuestion.all.map { $0.domain })
        XCTAssertEqual(domains, Set(DomainID.allCases))
    }
}
