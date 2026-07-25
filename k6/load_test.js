import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 50,
  duration: '10s',
  thresholds: {
    // 95% of requests must complete below 500ms
    http_req_duration: ['p(95)<500'],
    // 1% or less of requests can fail
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('http://localhost:4000/api/health');
  check(res, {
    'status was 200': (r) => r.status == 200,
  });
  sleep(1);
}
