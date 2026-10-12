const database = db.getSiblingDB("benchmark");
const baseDate = Date.UTC(2025, 0, 1);
const batchSize = 1000;

function seed(name, total, makeRecord) {
    const collection = database.getCollection(name);

    const latest = collection.find({}, {_id: 1})
        .sort({_id: -1}).limit(1).toArray();

    const start = latest.length
        ? latest[0]._id.toNumber() + 1
        : 1;

    if (start > total + 1) {
        throw new Error("Unexpected records in " + name);
    }

    print(name + ": resuming at " + start);

    for (let n = start; n <= total; n += batchSize) {
        const records = [];

        for (let i = n; i <= Math.min(total, n + batchSize - 1); i++) {
            records.push(makeRecord(i));
        }

        collection.insertMany(records, {ordered: true});

        if ((n - 1) % 100000 === 0) {
            print(name + ": inserted through " +
                Math.min(total, n + batchSize - 1));
        }
    }

    if (collection.countDocuments({}) !== total) {
        throw new Error("Incorrect final count for " + name);
    }

    print(name + ": verified " + total);
}

seed("benchmark_parent", 100000, n => ({
    _id: NumberLong(String(n)),
    id: NumberLong(String(n)),
    account_number: NumberLong(String(((n * 7919) % 10000) + 1)),
    status: ["complete", "active", "pending", "archived"][n % 4],
    created_at: new Date(baseDate + (n % 31536000) * 1000),
    payload: "P".repeat(256)
}));

seed("benchmark_child", 500000, n => ({
    _id: NumberLong(String(n)),
    id: NumberLong(String(n)),
    parent_id: NumberLong(String(((n - 1) % 100000) + 1)),
    sequence_number: ((n - 1) % 10) + 1,
    value_number: (n * 37) % 100000,
    payload: "C".repeat(512)
}));

seed("benchmark_event", 1000000, n => ({
    _id: NumberLong(String(n)),
    id: NumberLong(String(n)),
    parent_id: NumberLong(String(((n - 1) % 100000) + 1)),
    event_type: ["update", "sync", "review"][n % 3],
    event_time: new Date(baseDate + (n % 31536000) * 1000),
    payload: "E".repeat(256)
}));

database.benchmark_parent.createIndex({account_number: 1});
database.benchmark_parent.createIndex({status: 1});
database.benchmark_child.createIndex({parent_id: 1});
database.benchmark_event.createIndex({parent_id: 1});

const password = process.env.MONGO_BENCH_PASSWORD;
if (!password) throw new Error("Missing MongoDB benchmark password");

if (!database.getUser("benchmark")) {
    database.createUser({
        user: "benchmark",
        pwd: password,
        roles: [{role: "readWrite", db: "benchmark"}]
    });
}

print("MongoDB 1,600,000-record seed COMPLETE");
