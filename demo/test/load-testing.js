import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 10 },
        { duration: '3m', target: 20 },
        { duration: '30s', target: 0 },
    ],
};

export default function () {
    let url = 'http://host.docker.internal:5566/api/user'
    let res = http.get(url);
    check(res, { 'status was 200': (r) => r.status == 200 });
    sleep(1);
}

