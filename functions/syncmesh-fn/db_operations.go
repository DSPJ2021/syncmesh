package function

import (
	"context"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"time"
)

// getSensorsInTimeRange for a given mongodb collection
func (db mongoDB) getSensorsInTimeRange(startTime time.Time, endTime time.Time, limit int) (interface{}, error) {
	var sensors []SensorModel
	var err error

	ctx, _ := context.WithTimeout(context.Background(), 90*time.Second)
	cur, err := db.collection.Find(ctx, bson.M{
		"timestamp": bson.M{
			"$gte": startTime,
			"$lte": endTime,
		},
	}, options.Find().SetLimit(int64(limit)))
	if err != nil {
		return nil, err
	}
	for cur.Next(ctx) {
		var sensor SensorModel
		err = cur.Decode(&sensor)
		if err != nil {
			return nil, err
		}
		sensors = append(sensors, sensor)
	}
	if err = cur.Err(); err != nil {
		return nil, err
	}
	err = cur.Close(ctx)
	if err != nil {
		return nil, err
	}
	return sensors, nil
}

// aggregateSensorsInTimeRange using averages and optional time ranges
func (db mongoDB) aggregateSensorsInTimeRange(startTime interface{}, endTime interface{}) (interface{}, error) {
	ctx, _ := context.WithTimeout(context.Background(), 90*time.Second)
	var averagesCursor *mongo.Cursor
	var err error
	// calculate averages for relevant values
	avgStage := bson.D{{"$group",
		bson.D{
			{"_id", "null"},
			{"average_humidity", bson.D{{"$avg", "$humidity"}}},
			{"average_pressure", bson.D{{"$avg", "$pressure"}}},
			{"average_temperature", bson.D{{"$avg", "$temperature"}}},
		}}}
	if startTime != nil && endTime != nil {
		// filter out items outside of start/end time bounds
		dateFilterStage := bson.D{{"$match",
			bson.D{{"timestamp",
				bson.D{
					{"$lte", endTime.(time.Time)},
					{"$gte", startTime.(time.Time)}},
			}}}}
		averagesCursor, err = db.collection.Aggregate(ctx, mongo.Pipeline{dateFilterStage, avgStage})
	} else {
		// aggregate without time range
		averagesCursor, err = db.collection.Aggregate(ctx, mongo.Pipeline{avgStage})
	}
	if err != nil {
		return nil, err
	}
	var averages []bson.M
	if err = averagesCursor.All(ctx, &averages); err != nil {
		return nil, err
	}
	return averages[0], nil
}

// getSensor for a given id
func (db mongoDB) getSensor(_id string) (interface{}, error) {
	var sensor SensorModel
	var err error

	id, err := primitive.ObjectIDFromHex(_id)
	if err != nil {
		return nil, err
	}
	q := bson.M{"_id": id}
	ctx, _ := context.WithTimeout(context.Background(), 30*time.Second)
	err = db.collection.FindOne(ctx, q).Decode(&sensor)
	if err != nil {
		return nil, err
	}
	return sensor, nil
}

// deleteSensorById with a given id
func (db mongoDB) deleteSensorById(_id string) (interface{}, error) {
	var sensor SensorModel
	var err error

	id, err := primitive.ObjectIDFromHex(_id)
	if err != nil {
		return nil, err
	}
	q := bson.M{"_id": id}
	ctx, _ := context.WithTimeout(context.Background(), 30*time.Second)
	err = db.collection.FindOneAndDelete(ctx, q).Decode(&sensor)
	if err != nil {
		return nil, err
	}
	return sensor, nil
}

// deleteSensorByReplicaId with a given replica ID
func (db mongoDB) deleteSensorByReplicaId(replicaID string) (interface{}, error) {
	var sensor SensorModel
	var err error
	q := bson.M{"replicaID": replicaID}
	ctx, _ := context.WithTimeout(context.Background(), 30*time.Second)
	err = db.collection.FindOneAndDelete(ctx, q).Decode(&sensor)
	if err != nil {
		return nil, err
	}
	return sensor, nil
}

// createSensors using a given list of sensors to add into the db
func (db mongoDB) createSensors(sensors []interface{}) (interface{}, error) {
	ctx, _ := context.WithTimeout(context.Background(), 90*time.Second)
	res, err := db.collection.InsertMany(ctx, sensors, options.InsertMany().SetOrdered(false))
	if err != nil {
		return nil, err
	}
	return res.InsertedIDs, nil
}

// update a sensor with an id or replica ID using a new body
func (db mongoDB) update(_id string, sensor interface{}, replicaID string) (interface{}, error) {
	var err error
	var updatedSensor SensorModel

	id, err := primitive.ObjectIDFromHex(_id)
	if err != nil {
		return nil, err
	}

	ctx, _ := context.WithTimeout(context.Background(), 90*time.Second)
	filter := bson.M{"_id": id}
	if replicaID != "" {
		filter = bson.M{"replicaID": replicaID}
	}
	update := bson.D{{"$set", sensor}}
	err = db.collection.FindOneAndUpdate(ctx, filter, update).Decode(&updatedSensor)
	if err != nil {
		return nil, err
	}
	return updatedSensor, nil
}

// deleteInTimeRange for deleting sensors in a given time range
func (db mongoDB) deleteInTimeRange(startTime time.Time, endTime time.Time) (interface{}, error) {
	ctx, _ := context.WithTimeout(context.Background(), 90*time.Second)
	res, err := db.collection.DeleteMany(ctx, bson.M{
		"timestamp": bson.M{
			"$gte": startTime,
			"$lte": endTime,
		},
	})
	if err != nil {
		return nil, err
	}
	return res.DeletedCount, nil
}

// getDocEstimate approximates the current number of documents in the collection
func (db mongoDB) getDocEstimate() (interface{}, error) {
	ctx, _ := context.WithTimeout(context.Background(), 30*time.Second)
	opts := options.EstimatedDocumentCount().SetMaxTime(5 * time.Second)
	count, err := db.collection.EstimatedDocumentCount(ctx, opts)
	if err != nil {
		return nil, err
	}
	return count, nil
}
