public struct UnionFind {
    private var parent = [Int]()
    private var size = [Int]()
    
    init(capacity: Int) {
        parent.reserveCapacity(capacity)
        size.reserveCapacity(capacity);
    }
    
    public mutating func addSetWith(_ element: Int) {
        parent.append(parent.count)
        size.append(1)
    }
    
    public mutating func setByIndex(_ index: Int) -> Int {
        if parent[index] == index {
            return index
        } else {
            parent[index] = setByIndex(parent[index])
            return parent[index]
        }
    }
    
//    public mutating func setOf(_ element: Int) -> Int? {
//        if let indexOfElement = index[element] {
//            return setByIndex(indexOfElement)
//        } else {
//            return nil
//        }
//    }
    
    public mutating func unionSetsContaining(_ firstElement: Int, and secondElement: Int) {
        let firstSet = setByIndex(firstElement)
        let secondSet = setByIndex(secondElement)
        
        if firstSet != secondSet {
            if size[firstSet] < size[secondSet] {
                parent[firstSet] = secondSet
                size[secondSet] += size[firstSet]
            } else {
                parent[secondSet] = firstSet
                size[firstSet] += size[secondSet]
            }
        }
    }
    
    public mutating func inSameSet(_ firstElement: Int, and secondElement: Int) -> Bool {
        return setByIndex(firstElement) == setByIndex(secondElement)
    }
}
