# === utils/flow_utils.py ===
import torch
from torch.utils.data import DataLoader, TensorDataset
from nflows.distributions import StandardNormal
from nflows.transforms import CompositeTransform, MaskedAffineAutoregressiveTransform
from nflows.flows import Flow

def build_nf_model(input_dim, hidden_features=16, num_blocks=2):
    transform = CompositeTransform([
        MaskedAffineAutoregressiveTransform(features=input_dim, hidden_features=hidden_features)
        for _ in range(num_blocks)
    ])
    return Flow(transform, StandardNormal([input_dim]))

def train_nf_model(residuals, cond_features=None, model_cfg={}, window_cfg=None, save_path=None):
    x = torch.tensor(residuals, dtype=torch.float32).unsqueeze(1)
    dataset = TensorDataset(x)
    loader = DataLoader(dataset, batch_size=model_cfg.get("batch_size", 128), shuffle=True)

    flow = build_nf_model(input_dim=1, 
                          hidden_features=model_cfg.get("hidden_features", 32),
                          num_blocks=model_cfg.get("num_blocks", 4))

    optimizer = torch.optim.Adam(flow.parameters(), lr=model_cfg.get("lr", 1e-3))

    for epoch in range(model_cfg.get("epochs", 500)):
        for batch in loader:
            x_batch = batch[0]
            loss = -flow.log_prob(inputs=x_batch).mean()
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
    if save_path:
        torch.save(flow.state_dict(), os.path.join(save_path, "nf_model.pt"))
    return flow

def generate_residuals(flow, n=1000):
    with torch.no_grad():
        samples = flow.sample(n)
    return samples.numpy().flatten()

