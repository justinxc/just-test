import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '15s', target: 3 },
        { duration: '300s', target: 3 },
        { duration: '15s', target: 0 },
    ],
};

export default function () {
    let url = 'http://host.docker.internal:3333/?echo_code=200-200-400-500'
    let res = http.get(url);

    check(res, { 'status was 2xx': (r) => r.status >= 200 && r.status <= 299 });
    check(res, { 'status was 4xx': (r) => r.status >= 400 && r.status <= 499 });
    check(res, { 'status was 5xx': (r) => r.status >= 500 && r.status <= 599 });

    sleep(Math.random() * 3);
}

