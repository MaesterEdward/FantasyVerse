### 📘 Project README

```markdown
# FantasyVerse League 🏈🧙‍♂️

**FantasyVerse League** is a smart contract-based platform for managing decentralized fantasy sports leagues in the Metaverse. Built on the Stacks blockchain using Clarity, it enables users to create and join leagues, draft virtual athletes, record weekly performance stats, and earn STX rewards based on performance — all without relying on centralized intermediaries.

## 🚀 Features

- **League Creation:** Anyone can create a league with custom settings (entry fee, duration, roster size, etc.).
- **Secure Enrollment:** Managers can join leagues during the registration phase and pay entry fees securely.
- **Live Drafting:** Managers draft athletes during the draft phase, with ownership tracked on-chain.
- **Stat Recording:** Platform admins can record weekly athlete performance stats.
- **Automated Scoring:** Weekly manager scores are computed based on real (or simulated) stats.
- **Prize Distribution:** After a season ends, STX payouts are distributed to top-performing managers.
- **Platform Governance:** Includes system lock, fee management, and platform-admin control functions.

## 📦 Tech Stack

- **Language:** [Clarity](https://docs.stacks.co/docs/write-smart-contracts/clarity-overview/)
- **Blockchain:** [Stacks](https://www.stacks.co/) (built on Bitcoin)
- **Token:** STX (used for entry fees, prize pool, and payouts)
- **Data Structures:** Maps for leagues, managers, athletes, rosters, stats, and payouts.

## 📄 Contract Structure

- `create-league`: Define new leagues with rules and prize structures.
- `join-league`: Allows users to register as managers by paying the entry fee.
- `start-draft` / `draft-athlete`: Begins the draft phase and assigns athletes to rosters.
- `register-athlete`: Admin-only function to onboard new athletes into the registry.
- `record-athlete-stats`: Admin updates stats weekly for athletes.
- `calculate-weekly-score`: Computes manager's weekly scores from athlete stats.
- `complete-season`: Locks in the league and enables payouts.
- `calculate-payout` / `claim-payout`: View and claim winnings for top performers.
- `set-platform-fee` / `withdraw-platform-fees`: Admin fee handling.

## 📊 Scoring Breakdown

- 1 point per 25 passing yards
- 4 points per passing touchdown
- 1 point per 10 rushing yards
- 6 points per rushing touchdown
- 1 point per 10 receiving yards
- 6 points per receiving touchdown
- 3 points per field goal

## 🔐 Access Control

- Only the platform admin can:
  - Set platform fee
  - Lock/unlock the system
  - Register athletes
  - Record stats
  - Withdraw platform fees

- Only league commissioners or the platform admin can:
  - Start draft
  - Start season
  - Complete season

## ⚠️ Error Codes

Custom error constants like:
- `ERR-LEAGUE-NOT-FOUND`
- `ERR-DRAFT-CLOSED`
- `ERR-INVALID-MANAGER`
- `ERR-INSUFFICIENT-FUNDS`
- `ERR-SEASON-NOT-COMPLETE`
...and many more, for comprehensive error handling.

## 📌 TODO (Future Enhancements)

- Athlete trading system between managers
- Automated tie-breakers and ranking logic
- NFT integration for athlete collectibles
- Decentralized oracle integration for real-world stat updates
- In-game metaverse visualizations

## 🧑‍💼 Admin Instructions

1. Deploy the contract on the Stacks testnet/mainnet.
2. Use `set-platform-admin` to configure the initial platform admin.
3. Register real or fictional athletes using `register-athlete`.
4. Guide users to create and join leagues.
5. During season play, record weekly stats and manage payout processes.

