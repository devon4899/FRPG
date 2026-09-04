# Security policy

## Supported code

RPGFit is pre-release. Security and privacy fixes are applied to the latest
state of the `main` branch; older commits and the original prototype are not
maintained separately.

## Report a vulnerability privately

Please do not open a public issue for a suspected vulnerability or a report
that contains personal workout data. Use GitHub's
[private vulnerability report](https://github.com/devon4899/FRPG/security/advisories/new).
If that form is unavailable, send a concise report to
`devoncheng8@gmail.com`. Include:

- The affected feature and app version or commit.
- Reproduction steps and the expected versus observed behavior.
- The device and OS version used for testing.
- The practical impact, especially any data disclosure, data-loss, or reward-
  integrity risk.
- A minimal proof of concept with personal information removed.

You should receive an acknowledgement as soon as practical. Please allow time
to reproduce and correct the issue before publishing details.

## Security and privacy boundaries

RPGFit stores its primary save on device, uses no analytics or advertising
SDKs, requests no Apple Health read access, and contacts CloudKit only for a
user-requested backup action. Reports that contradict one of those guarantees
are treated as security or privacy issues even when no conventional exploit is
involved.

The app is a fitness log, not a medical device. Reports about training advice
or individual exercise suitability are outside this policy unless they arise
from a software defect or misleading app behavior.
