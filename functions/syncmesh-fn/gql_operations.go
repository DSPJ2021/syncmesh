package function

import (
	"github.com/graphql-go/graphql"
	"time"
)

func getSensors(p graphql.ResolveParams) (interface{}, error) {
	var err error
	var results interface{}
	limit := p.Args["limit"]
	if limit == nil {
		limit = 0
	}
	results, err = db.getSensors(limit.(int))
	if err != nil {
		return nil, err
	}
	return results, nil
}

func getSensor(p graphql.ResolveParams) (interface{}, error) {
	var err error
	var results interface{}
	id := p.Args["_id"].(string)
	results, err = db.getSensor(id)
	if err != nil {
		return nil, err
	}
	return results, nil
}

func getSensorsInTimeRange(p graphql.ResolveParams) (interface{}, error) {
	var err error
	var results interface{}
	limit := p.Args["limit"]
	if limit == nil {
		limit = 0
	}
	startDate := p.Args["start_time"].(time.Time)
	endDate := p.Args["end_time"].(time.Time)
	results, err = db.getSensorsInTimeRange(startDate, endDate, limit.(int))
	if err != nil {
		return nil, err
	}
	return results, nil
}