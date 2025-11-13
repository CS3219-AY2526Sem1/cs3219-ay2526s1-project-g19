from confluent_kafka import Consumer


if __name__=="__main__":
    config = {
        "bootstrap.servers": "peerprep_kafka:9092",
        "group.id": "foo",
        "auto.offset.reset": "earliest"
    }
    consumer = Consumer(config)

    try:
        consumer.subscribe(["match.found"])

        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is None: continue

            if msg.error():
                print("Error: {}".format(msg.error()))
            else:
                # Get the key and value as bytes
                key = msg.key()
                value = msg.value()

                # Decode bytes to string if your messages are UTF-8
                key_str = key.decode('utf-8') if key else None
                value_str = value.decode('utf-8') if value else None

                print(f"Received message: key={key_str}, value={value_str}, topic={msg.topic()}, partition={msg.partition()}, offset={msg.offset()}")

    except KeyboardInterrupt:
        pass
    finally:
        # Close down consumer to commit final offsets.
        consumer.close()
