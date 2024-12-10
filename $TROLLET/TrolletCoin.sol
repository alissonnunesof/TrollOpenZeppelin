// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Dependências do OpenZeppelin referenciadas localmente para confiabilidade
import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";

contract TrolletCoin is ERC20, Ownable, ReentrancyGuard {
    uint256 private constant TOTAL_SUPPLY = 21_000_000 * 10**8; // Suprimento total com 8 decimais
    uint8 private constant DECIMALS = 8;

    // Endereços de alocação
    address public liquidityPool;
    address public airdropWallet;
    address public communityReserve;
    address public stakingRewards;
    address public founderTeamWallet;
    address public partnershipsWallet;

    // Detalhes do vesting
    uint256 public immutable vestingStart;
    uint256 public constant VESTING_DURATION = 24 * 30 days; // Vesting em 24 meses
    uint256 public constant LOCK_PERIOD = 12 * 30 days; // Bloqueio inicial de 12 meses
    uint256 public vestedTokensReleased;

    // Liberação gradual
    uint256 private immutable releaseStartTime;
    uint256 private constant RELEASE_DURATION = 15 * 365 days; // Liberação em 15 anos
    uint256 public releasedTokens;

    // Eventos para transparência
    event InitialAllocation(address indexed recipient, uint256 amount);
    event TokensReleased(uint256 amount, address indexed recipient);
    event VestingReleased(uint256 amount, address indexed recipient);

    constructor(
        address _liquidityPool,
        address _airdropWallet,
        address _communityReserve,
        address _stakingRewards,
        address _founderTeamWallet,
        address _partnershipsWallet
    ) ERC20("TrolletCoin", "TROLLET") Ownable(msg.sender) {
        require(_liquidityPool != address(0), "Invalid liquidityPool");
        require(_airdropWallet != address(0), "Invalid airdropWallet");
        require(_communityReserve != address(0), "Invalid communityReserve");
        require(_stakingRewards != address(0), "Invalid stakingRewards");
        require(_founderTeamWallet != address(0), "Invalid founderTeamWallet");
        require(_partnershipsWallet != address(0), "Invalid partnershipsWallet");

        // Configuração de endereços
        liquidityPool = _liquidityPool;
        airdropWallet = _airdropWallet;
        communityReserve = _communityReserve;
        stakingRewards = _stakingRewards;
        founderTeamWallet = _founderTeamWallet;
        partnershipsWallet = _partnershipsWallet;

        // Distribuição inicial do supply
        uint256 initialSupply = TOTAL_SUPPLY / 2;
        _mint(liquidityPool, (initialSupply * 40) / 100); // 40% Liquidity Pool
        emit InitialAllocation(liquidityPool, (initialSupply * 40) / 100);

        _mint(airdropWallet, (initialSupply * 25) / 100); // 25% Airdrop
        emit InitialAllocation(airdropWallet, (initialSupply * 25) / 100);

        _mint(communityReserve, (initialSupply * 15) / 100); // 15% Community Reserve
        emit InitialAllocation(communityReserve, (initialSupply * 15) / 100);

        _mint(partnershipsWallet, (initialSupply * 10) / 100); // 10% Partnerships
        emit InitialAllocation(partnershipsWallet, (initialSupply * 10) / 100);

        _mint(address(this), (initialSupply * 10) / 100); // 10% bloqueados para vesting dos fundadores

        releaseStartTime = block.timestamp; // Início da liberação gradual
        vestingStart = block.timestamp; // Início do vesting
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    // Função para consultar tokens liberáveis na liberação gradual
    function releasableGradualTokens() public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - releaseStartTime;
        uint256 totalReleasable = (TOTAL_SUPPLY / 2) * elapsedTime / RELEASE_DURATION;
        return totalReleasable > releasedTokens ? totalReleasable - releasedTokens : 0;
    }

    // Liberação gradual de tokens
    function releaseGradualTokens() external nonReentrant {
        uint256 tokensToRelease = releasableGradualTokens();
        require(tokensToRelease > 0, "No tokens to release");

        releasedTokens += tokensToRelease;

        // 100% dos tokens liberados vão para recompensas de staking
        _mint(stakingRewards, tokensToRelease);

        emit TokensReleased(tokensToRelease, stakingRewards);
    }

    // Função para consultar tokens liberáveis no vesting
    function releasableVestedTokens() public view returns (uint256) {
        if (block.timestamp < vestingStart + LOCK_PERIOD) return 0;
        uint256 elapsed = block.timestamp - (vestingStart + LOCK_PERIOD);
        uint256 totalVested = (TOTAL_SUPPLY / 2 * 10) / 100; // 10% do total supply
        uint256 vestedAmount = (totalVested * elapsed) / VESTING_DURATION;
        return vestedAmount > vestedTokensReleased ? vestedAmount - vestedTokensReleased : 0;
    }

    // Liberação de tokens para fundadores
    function releaseVestedTokens() external nonReentrant {
        uint256 tokensToRelease = releasableVestedTokens();
        require(tokensToRelease > 0, "No tokens to release");

        vestedTokensReleased += tokensToRelease;
        _transfer(address(this), founderTeamWallet, tokensToRelease);

        emit VestingReleased(tokensToRelease, founderTeamWallet);
    }
}
