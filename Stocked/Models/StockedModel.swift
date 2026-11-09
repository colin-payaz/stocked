import CoreData

/// The Core Data model, defined in code. Every attribute is optional or has a
/// default, and every relationship is optional with an inverse, as iCloud sync requires.
enum StockedModel {
    static let shared: NSManagedObjectModel = {
        let kitchen = NSEntityDescription()
        kitchen.name = "Kitchen"
        kitchen.managedObjectClassName = NSStringFromClass(Kitchen.self)

        let item = NSEntityDescription()
        item.name = "Item"
        item.managedObjectClassName = NSStringFromClass(Item.self)

        func attribute(_ name: String, _ type: NSAttributeType, default value: Any? = nil) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.defaultValue = value
            attribute.isOptional = value == nil
            return attribute
        }

        let items = NSRelationshipDescription()
        items.name = "items"
        items.destinationEntity = item
        items.minCount = 0
        items.maxCount = 0
        items.isOptional = true
        items.deleteRule = .cascadeDeleteRule

        let owner = NSRelationshipDescription()
        owner.name = "kitchen"
        owner.destinationEntity = kitchen
        owner.minCount = 0
        owner.maxCount = 1
        owner.isOptional = true
        owner.deleteRule = .nullifyDeleteRule

        items.inverseRelationship = owner
        owner.inverseRelationship = items

        kitchen.properties = [
            attribute("uuid", .UUIDAttributeType),
            attribute("name", .stringAttributeType, default: "My Kitchen"),
            attribute("createdAt", .dateAttributeType),
            items,
        ]

        item.properties = [
            attribute("uuid", .UUIDAttributeType),
            attribute("name", .stringAttributeType, default: ""),
            attribute("barcode", .stringAttributeType, default: ""),
            attribute("categoryRaw", .stringAttributeType, default: "other"),
            attribute("quantity", .integer64AttributeType, default: 0),
            attribute("minQuantity", .integer64AttributeType, default: 0),
            attribute("onList", .booleanAttributeType, default: false),
            attribute("everStocked", .booleanAttributeType, default: false),
            attribute("bestBefore", .dateAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType),
            owner,
        ]

        let model = NSManagedObjectModel()
        model.entities = [kitchen, item]
        return model
    }()
}
